<?php

namespace Tests\Feature\Sales;

use App\Enums\NumberingDocumentType;
use App\Enums\SaleStatus;
use App\Models\NumberingSequence;
use App\Models\NumberingRule;
use App\Models\Sale;
use App\Services\Numbering\ReferenceNumberGenerator;
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
        $this->travelTo(now()->setDate(2026, 6, 1)->setTime(10, 0));
    }

    public function test_next_reference_uses_sequence_not_sale_count(): void
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

        // Gap: only one sale row exists, but the numbering sequence is already at 44.
        Sale::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'warehouse_id' => $warehouse->id,
            'processed_by' => $user->id,
            'reference' => 'POS-2026-000044',
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

        NumberingSequence::query()->create([
            'tenant_id' => $store->tenant_id,
            'branch_id' => null,
            'scope_key' => NumberingRule::TENANT_SCOPE,
            'document_type' => NumberingDocumentType::Pos,
            'period_key' => '2026',
            'last_value' => 44,
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

        $this->assertSame('POS-2026-000045', $result->sale->reference);
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
        $this->assertNotEmpty($reference);
        $this->assertStringStartsWith('POS-2026-', $reference);

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

    public function test_generator_preview_matches_next_allocation(): void
    {
        $preview = app(ReferenceNumberGenerator::class)->preview(
            NumberingDocumentType::Pos,
            $this->fixture['tenant']->id,
            $this->fixture['branch']->id,
        );

        $this->assertSame('POS-2026-000001', $preview);
    }
}
