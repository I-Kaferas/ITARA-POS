<?php

namespace Tests\Feature\Sync;

use App\Models\StockBalance;
use App\Models\SyncEvent;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PosStockPushTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('pos-stock', 'pos-stock@test.local');
    }

    public function test_stock_push_applies_delta_idempotently(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 100,
            'unit_cost' => 100,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();

        $movementUuid = (string) Str::uuid();
        $opId = (string) Str::uuid();
        $operation = [
            'id' => $opId,
            'entity_type' => 'stock',
            'entity_id' => $movementUuid,
            'operation' => 'create',
            'payload' => [
                'idempotency_key' => $movementUuid,
                'product_id' => $product->id,
                'quantity' => -7,
                'delta' => -7,
                'type' => 'ADJUSTMENT_OUT',
                'pos_id' => 'pos-device-1',
                'occurred_at' => now()->toIso8601String(),
                'warehouse_id' => $warehouse->id,
            ],
        ];

        $first = $this->postJson('/api/v1/sync/push', ['operations' => [$operation]], $headers)->assertOk();
        $first->assertJsonPath('data.results.0.status', 'synced');
        $this->assertSame(93, $this->onHand($warehouse->id, $product->id));

        // Duplicate UUID must not double-apply.
        $second = $this->postJson('/api/v1/sync/push', ['operations' => [$operation]], $headers)->assertOk();
        $second->assertJsonPath('data.results.0.status', 'synced');
        $second->assertJsonPath('data.results.0.already_processed', true);
        $this->assertSame(93, $this->onHand($warehouse->id, $product->id));
        $this->assertSame(1, SyncEvent::query()->where('entity_type', 'stock')->where('entity_id', $movementUuid)->count());
    }

    public function test_two_pos_deltas_on_same_product_accumulate(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 50,
            'unit_cost' => 100,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();

        $ops = [];
        foreach ([-3, -5] as $delta) {
            $uuid = (string) Str::uuid();
            $ops[] = [
                'id' => (string) Str::uuid(),
                'entity_type' => 'stock',
                'entity_id' => $uuid,
                'operation' => 'create',
                'payload' => [
                    'idempotency_key' => $uuid,
                    'product_id' => $product->id,
                    'quantity' => $delta,
                    'type' => 'ADJUSTMENT_OUT',
                    'pos_id' => 'pos-'.abs($delta),
                    'warehouse_id' => $warehouse->id,
                    'occurred_at' => now()->toIso8601String(),
                ],
            ];
        }

        $this->postJson('/api/v1/sync/push', ['operations' => $ops], $headers)->assertOk();
        $this->assertSame(42, $this->onHand($warehouse->id, $product->id));
    }

    public function test_negative_stock_is_reported_as_conflict_without_blocking_batch(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 2,
            'unit_cost' => 100,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();

        $badUuid = (string) Str::uuid();
        $okUuid = (string) Str::uuid();
        $response = $this->postJson('/api/v1/sync/push', [
            'operations' => [
                [
                    'id' => (string) Str::uuid(),
                    'entity_type' => 'stock',
                    'entity_id' => $badUuid,
                    'operation' => 'create',
                    'payload' => [
                        'idempotency_key' => $badUuid,
                        'product_id' => $product->id,
                        'quantity' => -10,
                        'type' => 'ADJUSTMENT_OUT',
                        'warehouse_id' => $warehouse->id,
                        'occurred_at' => now()->toIso8601String(),
                    ],
                ],
                [
                    'id' => (string) Str::uuid(),
                    'entity_type' => 'stock',
                    'entity_id' => $okUuid,
                    'operation' => 'create',
                    'payload' => [
                        'idempotency_key' => $okUuid,
                        'product_id' => $product->id,
                        'quantity' => 1,
                        'type' => 'ADJUSTMENT_IN',
                        'warehouse_id' => $warehouse->id,
                        'occurred_at' => now()->toIso8601String(),
                    ],
                ],
            ],
        ], $headers)->assertOk();

        $response->assertJsonPath('data.results.0.status', 'conflict');
        $response->assertJsonPath('data.results.0.conflict_code', 'negative_stock');
        $response->assertJsonPath('data.results.1.status', 'synced');
        // Initial 2 unchanged by conflicted out, then +1 applied.
        $this->assertSame(3, $this->onHand($warehouse->id, $product->id));
        $this->assertSame(0, SyncEvent::query()->where('entity_id', $badUuid)->count());
    }

    public function test_cashier_shift_ack_recognizes_client_uuid(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $register = \App\Models\CashRegister::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'name' => 'Caisse test',
            'code' => 'POS-ACK',
            'is_active' => true,
        ]);

        $localShiftId = (string) Str::uuid();
        $shift = \App\Models\CashierShift::query()->create([
            'tenant_id' => $store->tenant_id,
            'cash_register_id' => $register->id,
            'opened_by' => $this->fixture['user']->id,
            'client_uuid' => $localShiftId,
            'opening_balance' => 0,
            'status' => 'open',
            'opened_at' => now(),
        ]);

        $opId = 'shift-open-'.$localShiftId;
        $ack = $this->postJson('/api/v1/sync/ack', [
            'operations' => [[
                'id' => $opId,
                'entity_type' => 'cashier_shift',
                'entity_id' => $localShiftId,
                'server_id' => $shift->id,
            ]],
        ], $headers)->assertOk();
        $ack->assertJsonPath('data.acknowledged_ids.0', $opId);

        // Unknown shift must not be ACK'd.
        $missing = $this->postJson('/api/v1/sync/ack', [
            'operations' => [[
                'id' => 'shift-open-missing',
                'entity_type' => 'cashier_shift',
                'entity_id' => (string) Str::uuid(),
            ]],
        ], $headers)->assertOk();
        $this->assertContains('shift-open-missing', $missing->json('data.missing_ids'));
    }

    public function test_batch_continues_when_one_stock_op_fails(): void
    {
        $headers = $this->storeHeaders();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->importToStore($store);

        $okUuid = (string) Str::uuid();
        $badUuid = (string) Str::uuid();

        $response = $this->postJson('/api/v1/sync/push', [
            'operations' => [
                [
                    'id' => (string) Str::uuid(),
                    'entity_type' => 'stock',
                    'entity_id' => $badUuid,
                    'operation' => 'create',
                    'payload' => [
                        'idempotency_key' => $badUuid,
                        'product_id' => (string) Str::uuid(), // missing product
                        'quantity' => -1,
                        'type' => 'ADJUSTMENT_OUT',
                        'warehouse_id' => $warehouse->id,
                    ],
                ],
                [
                    'id' => (string) Str::uuid(),
                    'entity_type' => 'stock',
                    'entity_id' => $okUuid,
                    'operation' => 'create',
                    'payload' => [
                        'idempotency_key' => $okUuid,
                        'product_id' => $product->id,
                        'quantity' => 4,
                        'type' => 'ADJUSTMENT_IN',
                        'warehouse_id' => $warehouse->id,
                        'occurred_at' => now()->toIso8601String(),
                    ],
                ],
            ],
        ], $headers)->assertOk();

        $response->assertJsonPath('data.results.0.status', 'failed');
        $response->assertJsonPath('data.results.1.status', 'synced');
        $this->assertSame(4, $this->onHand($warehouse->id, $product->id));
    }

    private function onHand(string $warehouseId, string $productId): int
    {
        return (int) StockBalance::query()
            ->where('warehouse_id', $warehouseId)
            ->where('product_id', $productId)
            ->sum('quantity_on_hand');
    }

    private function storeHeaders(): array
    {
        return [
            ...$this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']),
            'X-Store-ID' => $this->fixture['store']->id,
        ];
    }
}
