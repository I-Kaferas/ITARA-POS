<?php

namespace Tests\Feature\Sales;

use App\Enums\SaleStatus;
use App\Models\Sale;
use App\Services\Sales\SaleEngine;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class SaleReferenceAllocationTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('saleref', 'saleref@test.local');
    }

    public function test_next_reference_uses_max_suffix_not_count(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $user = $this->fixture['user'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 50,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        // Gap: only one sale exists, but its reference is SAL-000009 (count+1 would wrongly reuse 000009).
        Sale::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'warehouse_id' => $warehouse->id,
            'processed_by' => $user->id,
            'reference' => 'SAL-000009',
            'status' => SaleStatus::Completed,
            'subtotal' => 1000,
            'tax_total' => 0,
            'discount_total' => 0,
            'fees_total' => 0,
            'total' => 1000,
            'currency' => 'USD',
            'idempotency_key' => (string) Str::uuid(),
            'completed_at' => now(),
        ]);

        $this->assertSame(1, Sale::query()->where('tenant_id', $store->tenant_id)->count());

        $result = app(SaleEngine::class)->create($store, [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 1000],
            ],
        ], $user);

        $this->assertSame('SAL-000010', $result->sale->reference);
    }

    public function test_sync_push_is_idempotent_for_same_key(): void
    {
        $headers = array_merge(
            $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']),
            ['X-Store-ID' => $this->fixture['store']->id],
        );
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 50,
            'unit_cost' => 500,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();

        $idempotencyKey = (string) Str::uuid();
        $operation = [
            'id' => (string) Str::uuid(),
            'entity_type' => 'sale',
            'entity_id' => $idempotencyKey,
            'operation' => 'create',
            'payload' => [
                'idempotency_key' => $idempotencyKey,
                'warehouse_id' => $warehouse->id,
                'items' => [
                    ['product_id' => $product->id, 'quantity' => 1],
                ],
                'payments' => [
                    ['method' => 'cash', 'amount' => 1000],
                ],
            ],
        ];

        $first = $this->postJson('/api/v1/sync/push', [
            'operations' => [$operation],
        ], $headers)->assertOk();

        $first->assertJsonPath('data.results.0.status', 'synced');
        $serverId = $first->json('data.results.0.server_id');
        $reference = $first->json('data.results.0.reference');

        $second = $this->postJson('/api/v1/sync/push', [
            'operations' => [$operation],
        ], $headers)->assertOk();

        $second->assertJsonPath('data.results.0.status', 'synced');
        $second->assertJsonPath('data.results.0.server_id', $serverId);
        $second->assertJsonPath('data.results.0.reference', $reference);

        $this->assertSame(
            1,
            Sale::query()->where('tenant_id', $store->tenant_id)->where('idempotency_key', $idempotencyKey)->count()
        );
    }
}
