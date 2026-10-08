<?php

namespace Tests\Feature\Sales;

use App\Models\Sale;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class SaleIdempotencyTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('sale-idem', 'sale-idem@test.local');
    }

    public function test_sales_have_unique_idempotency_key(): void
    {
        $this->assertTrue(Schema::hasColumn('sales', 'idempotency_key'));
        $this->assertTrue(Schema::hasColumn('transactions', 'idempotency_key'));

        $indexes = collect(Schema::getConnection()->getSchemaBuilder()->getIndexes('sales'))
            ->pluck('name')
            ->all();

        $this->assertContains('sales_tenant_idempotency_unique', $indexes);
    }

    public function test_duplicate_sale_request_returns_already_processed_without_creating_another(): void
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
            'quantity' => 20,
            'unit_cost' => 500,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();

        $idempotencyKey = (string) Str::uuid();
        $payload = [
            'idempotency_key' => $idempotencyKey,
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 1000],
            ],
        ];

        $first = $this->postJson("/api/v1/stores/{$store->id}/sales", $payload, $headers)
            ->assertCreated()
            ->assertJsonPath('data.already_processed', false)
            ->assertJsonPath('data.idempotency_key', $idempotencyKey);

        $saleId = $first->json('data.transaction_id');
        $this->assertNotEmpty($saleId);
        $this->assertSame($saleId, $first->json('data.sale.id'));

        $second = $this->postJson("/api/v1/stores/{$store->id}/sales", $payload, $headers)
            ->assertOk()
            ->assertJsonPath('data.already_processed', true)
            ->assertJsonPath('data.message', 'Already processed')
            ->assertJsonPath('data.transaction_id', $saleId)
            ->assertJsonPath('data.idempotency_key', $idempotencyKey)
            ->assertJsonPath('data.uuid', $idempotencyKey);

        $this->assertSame($saleId, $second->json('data.sale.id'));
        $this->assertSame(1, Sale::query()->where('tenant_id', $store->tenant_id)->count());
        $this->assertSame(1, Sale::query()->where('idempotency_key', $idempotencyKey)->count());
    }

    public function test_offline_replay_marks_already_processed(): void
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
            'quantity' => 20,
            'unit_cost' => 500,
        ], $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']))->assertCreated();

        $uuid = (string) Str::uuid();
        $operation = [
            'id' => $uuid,
            'client_uuid' => $uuid,
            'domain' => 'pos',
            'entity_type' => 'sale',
            'entity_id' => $uuid,
            'operation' => 'create',
            'payload' => [
                'idempotency_key' => $uuid,
                'warehouse_id' => $warehouse->id,
                'items' => [
                    ['product_id' => $product->id, 'quantity' => 1],
                ],
                'payments' => [
                    ['method' => 'cash', 'amount' => 1000],
                ],
            ],
        ];

        $first = $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)
            ->assertOk()
            ->assertJsonPath('data.results.0.status', 'synced')
            ->assertJsonPath('data.results.0.uuid', $uuid)
            ->assertJsonPath('data.results.0.idempotency_key', $uuid);

        $serverId = $first->json('data.results.0.server_id');
        $this->assertNotEmpty($serverId);

        $this->postJson('/api/v1/sync/offline', ['operations' => [$operation]], $headers)
            ->assertOk()
            ->assertJsonPath('data.results.0.status', 'synced')
            ->assertJsonPath('data.results.0.already_processed', true)
            ->assertJsonPath('data.results.0.message', 'Already processed')
            ->assertJsonPath('data.results.0.transaction_id', $serverId)
            ->assertJsonPath('data.results.0.server_id', $serverId);

        $this->assertSame(1, Sale::query()->where('idempotency_key', $uuid)->count());
    }
}
