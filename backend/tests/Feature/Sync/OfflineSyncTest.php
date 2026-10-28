<?php

namespace Tests\Feature\Sync;

use App\Models\CashierShift;
use App\Models\CashRegister;
use App\Models\DeskDocument;
use App\Models\Device;
use App\Models\InventoryMovement;
use App\Models\OfflineTransaction;
use App\Models\Promotion;
use App\Models\Sale;
use App\Models\StockBalance;
use App\Models\Tax;
use App\Models\Warehouse;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class OfflineSyncTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('offline', 'offline@test.local');
    }

    public function test_pos_sale_uuid_is_idempotent_and_rejects_reuse(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 20,
            'unit_cost' => 500,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();

        $uuid = (string) Str::uuid();
        $operation = $this->operation($uuid, 'pos', 'sale', 'create', [
            'idempotency_key' => $uuid,
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 1000],
            ],
        ]);

        $first = $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)->assertOk();
        $first->assertJsonPath('data.results.0.status', 'synced');
        $serverId = $first->json('data.results.0.server_id');

        $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)
            ->assertOk()
            ->assertJsonPath('data.results.0.status', 'synced')
            ->assertJsonPath('data.results.0.server_id', $serverId)
            ->assertJsonPath('data.results.0.already_processed', true)
            ->assertJsonPath('data.results.0.message', 'Already processed')
            ->assertJsonPath('data.results.0.uuid', $uuid)
            ->assertJsonPath('data.results.0.idempotency_key', $uuid)
            ->assertJsonPath('data.results.0.transaction_id', $serverId);

        $this->assertSame(1, Sale::query()->where('idempotency_key', $uuid)->count());
        $this->assertSame(1, OfflineTransaction::query()->where('client_uuid', $uuid)->count());
        $this->assertSame(19, $this->onHand($warehouse->id, $product->id));
        $this->assertSame(1, InventoryMovement::query()->where('product_id', $product->id)->where('movement_type', 'SALE')->count());

        $operation['payload']['payments'][0]['amount'] = 2500;
        $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)
            ->assertOk()
            ->assertJsonPath('data.results.0.status', 'conflict')
            ->assertJsonPath('data.results.0.conflict_code', 'uuid_payload_mismatch');

        $this->assertSame(1, Sale::query()->where('tenant_id', $store->tenant_id)->count());
        $this->assertSame(19, $this->onHand($warehouse->id, $product->id));
    }

    public function test_replayed_sale_does_not_decrement_stock_twice_and_two_devices_add_deltas(): void
    {
        $headers = $this->storeHeaders();
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->importToStore($this->fixture['store']);
        $this->stock($warehouse->id, $product->id, 20);

        $store = $this->fixture['store'];
        $deviceA = Device::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'branch_id' => $store->branch_id,
            'name' => 'Caisse A',
            'device_type' => 'pos',
            'identifier' => 'pos-device-a',
            'sync_token' => 'token-pos-device-a',
            'is_active' => true,
        ]);
        $deviceB = Device::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'branch_id' => $store->branch_id,
            'name' => 'Caisse B',
            'device_type' => 'pos',
            'identifier' => 'pos-device-b',
            'sync_token' => 'token-pos-device-b',
            'is_active' => true,
        ]);
        $deviceA->warehouses()->attach($warehouse->id);
        $deviceB->warehouses()->attach($warehouse->id);

        $firstId = (string) Str::uuid();
        $first = $this->operation($firstId, 'pos', 'sale', 'create', [
            'idempotency_key' => $firstId,
            'warehouse_id' => $warehouse->id,
            'device_id' => $deviceA->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 2000],
            ],
        ]);
        $this->postJson('/api/v1/sync/offline', ['operations' => [$first]], $headers)->assertOk()
            ->assertJsonPath('data.results.0.status', 'synced');
        $this->postJson('/api/v1/sync/offline', ['operations' => [$first]], $headers)->assertOk()
            ->assertJsonPath('data.results.0.already_processed', true);
        $this->assertSame(18, $this->onHand($warehouse->id, $product->id));

        $secondId = (string) Str::uuid();
        $this->postJson('/api/v1/sync/offline', ['operations' => [
            $this->operation($secondId, 'pos', 'sale', 'create', [
                'idempotency_key' => $secondId,
                'warehouse_id' => $warehouse->id,
                'device_id' => $deviceB->id,
                'items' => [
                    ['product_id' => $product->id, 'quantity' => 3],
                ],
                'payments' => [
                    ['method' => 'cash', 'amount' => 3000],
                ],
            ]),
        ]], $headers)->assertOk()->assertJsonPath('data.results.0.status', 'synced');

        $this->assertSame(15, $this->onHand($warehouse->id, $product->id));
        $this->assertSame(2, InventoryMovement::query()->where('product_id', $product->id)->where('movement_type', 'SALE')->count());
    }

    public function test_offline_sale_uses_the_store_stock_not_another_depot(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $product = $this->fixture['product'];
        $product->importToStore($store);
        $storeStock = app(\App\Services\Inventory\StoreStockLocation::class)->forStore($store);
        $other = Warehouse::query()->create([
            'tenant_id' => $store->tenant_id,
            'branch_id' => $store->branch_id,
            'name' => 'Autre depot',
            'code' => 'OFFLINE-WH2',
            'is_active' => true,
        ]);
        $this->stock($storeStock->id, $product->id, 20);
        $this->stock($other->id, $product->id, 20);

        $uuid = (string) Str::uuid();
        $this->postJson('/api/v1/sync/offline', ['operations' => [
            $this->operation($uuid, 'pos', 'sale', 'create', [
                'idempotency_key' => $uuid,
                'items' => [
                    ['product_id' => $product->id, 'quantity' => 4],
                ],
                'payments' => [
                    ['method' => 'cash', 'amount' => 4000],
                ],
            ]),
        ]], $headers)->assertOk()->assertJsonPath('data.results.0.status', 'synced');

        $this->assertSame(16, $this->onHand($storeStock->id, $product->id));
        $this->assertSame(20, $this->onHand($other->id, $product->id));
        $sale = Sale::query()->where('idempotency_key', $uuid)->first();
        $this->assertSame($storeStock->id, $sale?->warehouse_id);

        $catalog = $this->getJson('/api/v1/stores/'.$store->id.'/pos/catalog', $headers)
            ->assertOk()
            ->assertJsonPath('data.sale_warehouse_id', $storeStock->id);

        $productRow = collect($catalog->json('data.products'))->firstWhere('product_id', $product->id);
        $this->assertSame(16, $productRow['quantity_on_hand'] ?? null);
        $stockLines = collect($catalog->json('data.stock'));
        $this->assertTrue($stockLines->every(fn (array $line) => $line['warehouse_id'] === $storeStock->id));
        $this->assertSame(16, (int) $stockLines->where('product_id', $product->id)->sum('quantity_on_hand'));
    }

    public function test_insufficient_stock_keeps_the_sale_as_a_conflict_without_decrement(): void
    {
        $headers = $this->storeHeaders();
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->importToStore($this->fixture['store']);
        $this->stock($warehouse->id, $product->id, 2);

        $uuid = (string) Str::uuid();
        $this->postJson('/api/v1/sync/offline', ['operations' => [
            $this->operation($uuid, 'pos', 'sale', 'create', [
                'idempotency_key' => $uuid,
                'warehouse_id' => $warehouse->id,
                'items' => [
                    ['product_id' => $product->id, 'quantity' => 5],
                ],
                'payments' => [
                    ['method' => 'cash', 'amount' => 5000],
                ],
            ]),
        ]], $headers)->assertOk()
            ->assertJsonPath('data.results.0.status', 'conflict')
            ->assertJsonPath('data.results.0.conflict_code', 'stock');

        $this->assertSame(2, $this->onHand($warehouse->id, $product->id));
        $this->assertNull(Sale::query()->where('idempotency_key', $uuid)->first());
        $this->assertSame(0, InventoryMovement::query()->where('product_id', $product->id)->where('movement_type', 'SALE')->count());
    }

    public function test_unpaid_order_syncs_without_a_payment(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $product = $this->fixture['product'];
        $product->importToStore($store);

        $uuid = (string) Str::uuid();
        $operation = $this->operation($uuid, 'pos', 'sale', 'hold', [
            'idempotency_key' => $uuid,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
        ]);

        $first = $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)->assertOk();
        $first->assertJsonPath('data.results.0.status', 'synced');
        $serverId = $first->json('data.results.0.server_id');

        $sale = Sale::query()->find($serverId);
        $this->assertNotNull($sale);
        $this->assertSame('pending', $sale->status->value);
        $this->assertSame('unpaid', $sale->payment_status->value);
        $this->assertSame(0, (int) $sale->paid_amount);

        $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)
            ->assertOk()
            ->assertJsonPath('data.results.0.status', 'synced')
            ->assertJsonPath('data.results.0.server_id', $serverId);

        $this->assertSame(1, Sale::query()->where('idempotency_key', $uuid)->count());

        $create = $this->operation((string) Str::uuid(), 'pos', 'sale', 'create', [
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                ['method' => 'unpaid', 'amount' => 1000],
            ],
        ]);
        $second = $this->postJson('/api/v1/sync/offline', ['operations' => [$create]], $headers)->assertOk();
        $second->assertJsonPath('data.results.0.status', 'synced');
        $unpaid = Sale::query()->find($second->json('data.results.0.server_id'));
        $this->assertSame('pending', $unpaid?->status->value);
        $this->assertSame('unpaid', $unpaid?->payment_status->value);
    }

    public function test_device_priced_sale_keeps_charged_tax_and_skips_unseen_promotion(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->update([
            'tax_id' => Tax::query()->create([
                'tenant_id' => $store->tenant_id,
                'name' => 'TVA 18%',
                'code' => 'TVA18-SYNC',
                'kind' => 'vat',
                'type' => 'percentage',
                'rate' => 18,
                'is_inclusive' => false,
                'is_active' => true,
            ])->id,
        ]);
        $product->importToStore($store);

        Promotion::query()->create([
            'tenant_id' => $store->tenant_id,
            'name' => 'Soldes -15%',
            'code' => 'SUMMER15-SYNC',
            'type' => 'percentage_discount',
            'discount_percent' => 15,
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addMonth(),
            'min_quantity' => 1,
            'is_active' => true,
        ]);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 20,
            'unit_cost' => 500,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();

        $saleKey = (string) Str::uuid();
        $paymentId = (string) Str::uuid();
        $response = $this->postJson('/api/v1/sync/push', [
            'operations' => [
                [
                    'id' => (string) Str::uuid(),
                    'entity_type' => 'sale',
                    'entity_id' => $saleKey,
                    'operation' => 'create',
                    'payload' => [
                        'idempotency_key' => $saleKey,
                        'warehouse_id' => $warehouse->id,
                        'items' => [
                            ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => 1000],
                        ],
                        'payments' => [
                            ['method' => 'cash', 'amount' => 1180],
                        ],
                    ],
                ],
                [
                    'id' => (string) Str::uuid(),
                    'entity_type' => 'payment',
                    'entity_id' => $paymentId,
                    'operation' => 'create',
                    'payload' => [
                        'sale_id' => $saleKey,
                        'method' => 'cash',
                        'amount' => 1180,
                    ],
                ],
            ],
        ], $headers)->assertOk();

        $response->assertJsonPath('data.results.0.status', 'synced');
        $response->assertJsonPath('data.results.1.status', 'synced');

        $sale = Sale::query()->find($response->json('data.results.0.server_id'));
        $this->assertNotNull($sale);
        $this->assertSame(1180, (int) $sale->total);
        $this->assertSame(180, (int) $sale->tax_total);

        $serverPriced = $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'id' => (string) Str::uuid(),
                'entity_type' => 'sale',
                'entity_id' => (string) Str::uuid(),
                'operation' => 'create',
                'payload' => [
                    'warehouse_id' => $warehouse->id,
                    'items' => [
                        ['product_id' => $product->id, 'quantity' => 1],
                    ],
                    'payments' => [
                        ['method' => 'cash', 'amount' => 1003],
                    ],
                ],
            ]],
        ], $headers)->assertOk();

        $serverPriced->assertJsonPath('data.results.0.status', 'synced');
        $discounted = Sale::query()->find($serverPriced->json('data.results.0.server_id'));
        $this->assertSame(1003, (int) $discounted?->total);
        $this->assertSame(153, (int) $discounted?->tax_total);
    }

    public function test_restaurant_order_keeps_the_client_uuid(): void
    {
        $headers = $this->storeHeaders();
        $orderUuid = (string) Str::uuid();
        $lineUuid = (string) Str::uuid();

        $response = $this->postJson('/api/v1/sync/offline', [
            'operations' => [
                $this->operation($orderUuid, 'restaurant', 'order', 'open_order', [
                    'action' => 'open_order',
                    'table_id' => 'table-1',
                    'client_uuid' => $orderUuid,
                ]),
                $this->operation($lineUuid, 'restaurant', 'order_line', 'add_line', [
                    'action' => 'add_line',
                    'order_id' => $orderUuid,
                    'name' => 'Brochette',
                    'unit_price' => 5000,
                    'quantity' => 1,
                    'course' => 'plat',
                    'client_uuid' => $lineUuid,
                ]),
            ],
        ], $headers)->assertOk();

        $response->assertJsonPath('data.results.0.status', 'synced');
        $response->assertJsonPath('data.results.1.status', 'synced');

        $order = DeskDocument::query()->where('code', $orderUuid)->first();
        $this->assertNotNull($order);
        $this->assertSame('order', $order->kind);
        $this->assertCount(1, $order->payload['lines'] ?? []);
        $this->assertSame($lineUuid, $order->payload['lines'][0]['id']);

        $this->postJson('/api/v1/sync/offline', [
            'operations' => [
                $this->operation($orderUuid, 'restaurant', 'order', 'open_order', [
                    'action' => 'open_order',
                    'table_id' => 'table-1',
                    'client_uuid' => $orderUuid,
                ]),
            ],
        ], $headers)->assertOk()->assertJsonPath('data.results.0.status', 'synced');

        $this->assertSame(1, DeskDocument::query()->where('kind', 'order')->where('code', $orderUuid)->count());
    }

    public function test_hotel_stale_reservation_can_keep_the_local_copy(): void
    {
        $headers = $this->storeHeaders();
        $uuid = (string) Str::uuid();

        $this->postJson('/api/v1/sync/offline', [
            'operations' => [
                $this->operation($uuid, 'hotel', 'reservation', 'create_reservation', [
                    'action' => 'create_reservation',
                    'room_id' => 'room-201',
                    'guest_name' => 'Aline',
                    'client_uuid' => $uuid,
                ]),
            ],
        ], $headers)->assertOk()->assertJsonPath('data.results.0.status', 'synced');

        $reservation = DeskDocument::query()->where('code', $uuid)->firstOrFail();
        DB::table('desk_documents')->where('id', $reservation->id)->update([
            'updated_at' => now()->addHour(),
        ]);

        $checkIn = (string) Str::uuid();
        $conflict = $this->postJson('/api/v1/sync/offline', [
            'operations' => [
                $this->operation($checkIn, 'hotel', 'reservation', 'check_in', [
                    'action' => 'check_in',
                    'reservation_id' => $uuid,
                    'client_uuid' => $checkIn,
                ], now()->subDay()->toIso8601String()),
            ],
        ], $headers)->assertOk();

        $conflict->assertJsonPath('data.results.0.status', 'conflict');
        $conflict->assertJsonPath('data.results.0.conflict_code', 'stale_version');
        $this->assertSame('confirmed', DeskDocument::query()->where('code', $uuid)->firstOrFail()->status);

        $this->postJson('/api/v1/sync/offline/resolve', [
            'client_uuid' => $checkIn,
            'resolution' => 'keep_local',
        ], $headers)->assertOk()->assertJsonPath('data.status', 'synced');

        $this->assertSame('checked_in', DeskDocument::query()->where('code', $uuid)->firstOrFail()->status);
    }

    public function test_cash_shift_open_replays_the_same_uuid(): void
    {
        $headers = $this->storeHeaders();
        $register = CashRegister::query()->create([
            'tenant_id' => $this->fixture['store']->tenant_id,
            'store_id' => $this->fixture['store']->id,
            'name' => 'Caisse 1',
            'code' => 'C1-OFF',
            'is_active' => true,
        ]);
        $uuid = (string) Str::uuid();
        $operation = $this->operation($uuid, 'cash_register', 'cashier_shift', 'open', [
            'cash_register_id' => $register->id,
            'opening_balance' => 15000,
            'client_uuid' => $uuid,
        ]);

        $first = $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)->assertOk();
        $first->assertJsonPath('data.results.0.status', 'synced');
        $shiftId = $first->json('data.results.0.server_id');

        $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)
            ->assertOk()
            ->assertJsonPath('data.results.0.status', 'synced')
            ->assertJsonPath('data.results.0.server_id', $shiftId);

        $this->assertSame(1, CashierShift::query()->where('cash_register_id', $register->id)->count());
        $opened = CashierShift::query()->find($shiftId);
        $this->assertSame($uuid, $opened?->client_uuid);
        $this->assertNotNull($opened?->branch_id);
        $this->assertSame($this->fixture['store']->branch_id, $opened?->branch_id);
        $this->assertSame($register->id, $opened?->cash_register_id);
        $this->assertNotNull($opened?->cashier_id);
        $this->assertNotNull($opened?->opened_at);

        $other = (string) Str::uuid();
        $this->postJson('/api/v1/sync/offline', [
            'operations' => [
                $this->operation($other, 'cash_register', 'cashier_shift', 'open', [
                    'cash_register_id' => $register->id,
                    'opening_balance' => 1000,
                    'client_uuid' => $other,
                ]),
            ],
        ], $headers)->assertOk()
            ->assertJsonPath('data.results.0.status', 'conflict')
            ->assertJsonPath('data.results.0.conflict_code', 'state_conflict');

        $this->assertSame(1, CashierShift::query()->where('cash_register_id', $register->id)->count());
    }

    public function test_period_close_replays_short_stock_and_zero_cash_ahead_of_payments(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->importToStore($store);
        $this->stock($warehouse->id, $product->id, 33);

        $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => 1000],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 0],
            ],
        ], $headers)->assertStatus(422);

        $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 39, 'unit_price' => 1000],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 39000],
            ],
        ], $headers)->assertStatus(422);

        $this->assertSame(33, $this->onHand($warehouse->id, $product->id));

        $saleKey = (string) Str::uuid();
        $paymentKey = (string) Str::uuid();
        $zeroPayment = (string) Str::uuid();

        $response = $this->postJson('/api/v1/sync/push', [
            'operations' => [
                [
                    'id' => $paymentKey,
                    'entity_type' => 'payment',
                    'entity_id' => $paymentKey,
                    'operation' => 'create',
                    'payload' => [
                        'sale_id' => $saleKey,
                        'method' => 'cash',
                        'amount' => 1000,
                    ],
                ],
                [
                    'id' => $zeroPayment,
                    'entity_type' => 'payment',
                    'entity_id' => $zeroPayment,
                    'operation' => 'create',
                    'payload' => [
                        'sale_id' => $saleKey,
                        'method' => 'cash',
                        'amount' => 0,
                    ],
                ],
                [
                    'id' => $saleKey,
                    'entity_type' => 'sale',
                    'entity_id' => $saleKey,
                    'operation' => 'create',
                    'payload' => [
                        'idempotency_key' => $saleKey,
                        'warehouse_id' => $warehouse->id,
                        'items' => [
                            ['product_id' => $product->id, 'quantity' => 39, 'unit_price' => 1000],
                        ],
                        'payments' => [
                            ['method' => 'cash', 'amount' => 0],
                        ],
                    ],
                ],
            ],
        ], $headers)->assertOk();

        $response->assertJsonPath('data.results.0.status', 'synced');
        $response->assertJsonPath('data.results.1.status', 'synced');
        $response->assertJsonPath('data.results.2.status', 'synced');

        $sale = Sale::query()->where('idempotency_key', $saleKey)->first();
        $this->assertNotNull($sale);
        $this->assertSame('completed', $sale->status->value ?? (string) $sale->status);
        $this->assertSame(39000, (int) $sale->total);
        $this->assertSame(39000, (int) $sale->paid_amount);
        $this->assertSame(-6, (int) StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->sum('quantity_on_hand'));
    }

    /** @param  array<string, mixed>  $payload */
    private function operation(string $uuid, string $domain, string $entityType, string $operation, array $payload, ?string $baseVersion = null): array
    {
        return [
            'id' => $uuid,
            'client_uuid' => $uuid,
            'domain' => $domain,
            'entity_type' => $entityType,
            'entity_id' => $uuid,
            'operation' => $operation,
            'payload' => $payload,
            'base_version' => $baseVersion,
        ];
    }

    private function stock(string $warehouseId, string $productId, int $quantity): void
    {
        $this->postJson("/api/v1/warehouses/{$warehouseId}/movements", [
            'product_id' => $productId,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => $quantity,
            'unit_cost' => 500,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();
    }

    private function onHand(string $warehouseId, string $productId): int
    {
        return (int) StockBalance::query()
            ->where('warehouse_id', $warehouseId)
            ->where('product_id', $productId)
            ->value('quantity_on_hand');
    }

    /** @return array<string, string> */
    private function storeHeaders(): array
    {
        return array_merge(
            $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']),
            ['X-Store-ID' => $this->fixture['store']->id],
        );
    }
}
