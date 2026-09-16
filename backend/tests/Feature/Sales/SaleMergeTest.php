<?php

namespace Tests\Feature\Sales;

use App\Enums\PosTableStatus;
use App\Enums\SaleStatus;
use App\Models\InventoryMovement;
use App\Models\PosTable;
use App\Models\Sale;
use App\Models\StockBalance;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class SaleMergeTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('merge', 'merge@test.local');
        $this->fixture['product']->importToStore($this->fixture['store']);
    }

    public function test_merge_two_pending_orders_consolidates_quantities(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];
        $product = $this->fixture['product'];

        $a = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 2]]);
        $b = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]]);

        $preview = $this->postJson("/api/v1/sales/{$a}/merge/preview", [
            'source_sale_id' => $b,
        ], $headers)->assertOk()->json('data');

        $this->assertSame(3, collect($preview['items'])->sum('quantity'));
        $this->assertSame(3000, $preview['totals']['total']);

        $merged = $this->postJson("/api/v1/sales/{$a}/merge", [
            'source_sale_id' => $b,
        ], $headers)->assertOk()->json('data');

        $this->assertSame($a, $merged['id']);
        $this->assertSame(3000, $merged['total']);
        $this->assertSame(3, collect($merged['items'])->sum('quantity'));

        $this->assertDatabaseHas('sales', [
            'id' => $b,
            'status' => SaleStatus::Merged->value,
            'merged_into_id' => $a,
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'sale.merged',
            'entity_id' => $a,
        ]);
        $this->assertSame(0, InventoryMovement::query()->count());
    }

    public function test_merge_same_table_and_different_tables(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];
        $product = $this->fixture['product'];
        $tableA = $this->makeTable('T-A');
        $tableB = $this->makeTable('T-B');

        $saleA = $this->openTableOrder($headers, $tableA);
        $this->putJson("/api/v1/sales/{$saleA}", [
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
        ], $headers)->assertOk();

        $saleB = $this->openTableOrder($headers, $tableB);
        $this->putJson("/api/v1/sales/{$saleB}", [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
        ], $headers)->assertOk();

        $this->postJson("/api/v1/sales/{$saleA}/merge", [
            'source_sale_id' => $saleB,
            'table_id' => $tableA->id,
            'confirm_different_customers' => true,
        ], $headers)->assertOk();

        $this->assertDatabaseHas('pos_tables', [
            'id' => $tableA->id,
            'status' => PosTableStatus::Occupied->value,
            'current_sale_id' => $saleA,
        ]);
        $this->assertDatabaseHas('pos_tables', [
            'id' => $tableB->id,
            'status' => PosTableStatus::Available->value,
            'current_sale_id' => null,
        ]);
        $this->assertDatabaseHas('sales', [
            'id' => $saleA,
            'table_id' => $tableA->id,
            'total' => 3000,
        ]);
    }

    public function test_different_customers_require_confirmation(): void
    {
        $headers = $this->headers();
        $product = $this->fixture['product'];
        $customerB = \App\Models\Customer::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'name' => 'Pierre',
            'email' => 'pierre-merge@test.local',
            'is_active' => true,
        ]);

        $a = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]], $this->fixture['customer']->id);
        $b = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]], $customerB->id);

        $this->postJson("/api/v1/sales/{$a}/merge", [
            'source_sale_id' => $b,
        ], $headers)->assertUnprocessable();

        $this->postJson("/api/v1/sales/{$a}/merge", [
            'source_sale_id' => $b,
            'confirm_different_customers' => true,
            'customer_id' => $this->fixture['customer']->id,
        ], $headers)->assertOk()->assertJsonPath('data.customer_id', $this->fixture['customer']->id);
    }

    public function test_paid_or_voided_orders_cannot_merge(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $pending = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]]);
        $paid = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'payments' => [['method' => 'cash', 'amount' => 1000]],
        ], $headers)->assertCreated()->json('data.sale.id');

        $this->postJson("/api/v1/sales/{$pending}/merge", [
            'source_sale_id' => $paid,
        ], $headers)->assertUnprocessable();

        $voided = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]]);
        Sale::query()->whereKey($voided)->update(['status' => SaleStatus::Voided]);

        $this->postJson("/api/v1/sales/{$pending}/merge", [
            'source_sale_id' => $voided,
        ], $headers)->assertUnprocessable();
    }

    public function test_merge_does_not_touch_stock_twice(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 20,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $a = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 2]]);
        $b = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 3]]);

        $before = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->value('quantity_on_hand');

        $this->postJson("/api/v1/sales/{$a}/merge", [
            'source_sale_id' => $b,
        ], $headers)->assertOk();

        $afterMerge = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->value('quantity_on_hand');
        $this->assertSame((int) $before, (int) $afterMerge);

        $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'sale_id' => $a,
            'warehouse_id' => $warehouse->id,
            'items' => [['product_id' => $product->id, 'quantity' => 5]],
            'payments' => [['method' => 'cash', 'amount' => 5000]],
        ], $headers)->assertCreated();

        $afterPay = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->value('quantity_on_hand');
        $this->assertSame((int) $before - 5, (int) $afterPay);
    }

    public function test_concurrent_merge_prevents_double_merge(): void
    {
        $headers = $this->headers();
        $product = $this->fixture['product'];
        $a = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]]);
        $b = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]]);
        $c = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]]);

        $this->postJson("/api/v1/sales/{$a}/merge", [
            'source_sale_id' => $b,
        ], $headers)->assertOk();

        $this->postJson("/api/v1/sales/{$a}/merge", [
            'source_sale_id' => $b,
        ], $headers)->assertUnprocessable();

        $this->postJson("/api/v1/sales/{$b}/merge", [
            'source_sale_id' => $c,
        ], $headers)->assertUnprocessable();
    }

    public function test_merge_candidates_endpoint(): void
    {
        $headers = $this->headers();
        $product = $this->fixture['product'];
        $a = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]]);
        $b = $this->createPending($headers, [['product_id' => $product->id, 'quantity' => 1]]);

        $this->getJson("/api/v1/sales/{$a}/merge-candidates", $headers)
            ->assertOk()
            ->assertJsonFragment(['id' => $b]);
    }

    /** @return array<string, string> */
    private function headers(): array
    {
        return $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
    }

    /** @param  list<array<string, mixed>>  $items */
    private function createPending(array $headers, array $items, ?string $customerId = null): string
    {
        $payload = [
            'items' => $items,
            'customer_id' => $customerId,
        ];

        return $this->postJson(
            "/api/v1/stores/{$this->fixture['store']->id}/sales/holds",
            $payload,
            $headers,
        )->assertCreated()->json('data.id');
    }

    private function makeTable(string $name): PosTable
    {
        $payload = $this->postJson("/api/v1/stores/{$this->fixture['store']->id}/pos/tables", [
            'name' => $name,
            'capacity' => 4,
        ], $this->headers())->assertCreated()->json('data');

        return PosTable::query()->findOrFail($payload['id']);
    }

    private function openTableOrder(array $headers, PosTable $table): string
    {
        return $this->postJson(
            "/api/v1/stores/{$this->fixture['store']->id}/pos/tables/{$table->id}/open",
            [],
            $headers,
        )->assertCreated()->json('data.sale.id');
    }
}
