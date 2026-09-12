<?php

namespace Tests\Feature\Sales;

use App\Events\SaleReturnCompleted;
use App\Models\AccountingEntry;
use App\Models\CustomerTransaction;
use App\Models\InventoryMovement;
use App\Models\Sale;
use App\Models\SaleReturn;
use App\Models\StockBalance;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class SalesPhase27Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('sales27', 'sales27@test.local');
    }

    public function test_phase27_sale_return_tables_exist(): void
    {
        foreach (['sale_returns', 'sale_return_items'] as $table) {
            $this->assertTrue(Schema::hasTable($table), "Missing table: {$table}");
        }
    }

    public function test_return_reasons_endpoint(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->getJson('/api/v1/returns/reasons', $headers)
            ->assertOk()
            ->assertJsonStructure(['data' => [['value', 'label']]]);
    }

    public function test_partial_return_restock_and_creates_records(): void
    {
        Event::fake([SaleReturnCompleted::class]);

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 50,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 5],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 5000],
            ],
        ], $headers)->assertCreated();

        $saleId = $saleResponse->json('data.sale.id');
        $saleItemId = $saleResponse->json('data.sale.items.0.id');

        $response = $this->postJson("/api/v1/sales/{$saleId}/returns", [
            'reason' => 'defective',
            'items' => [
                ['sale_item_id' => $saleItemId, 'quantity' => 2],
            ],
        ], $headers)->assertCreated();

        $response->assertJsonPath('data.sale_return.status', 'completed');
        $response->assertJsonPath('data.sale_return.total', 2000);
        $response->assertJsonPath('data.sale_return.reason', 'defective');

        $returnId = $response->json('data.sale_return.id');

        $this->assertDatabaseHas('sale_returns', [
            'id' => $returnId,
            'sale_id' => $saleId,
            'status' => 'completed',
        ]);
        $this->assertDatabaseCount('sale_return_items', 1);

        $this->assertDatabaseHas('inventory_movements', [
            'reference_type' => SaleReturn::class,
            'reference_id' => $returnId,
            'movement_type' => 'SALE_RETURN',
        ]);

        $balance = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->first();

        $this->assertSame(47, $balance->quantity_on_hand);

        $this->assertGreaterThan(0, AccountingEntry::query()->where('reference_id', $returnId)->count());
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'sale_return.completed',
            'entity_id' => $returnId,
        ]);

        Event::assertDispatched(SaleReturnCompleted::class);
    }

    public function test_cannot_return_more_than_sold_quantity(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
            'unit_cost' => 500,
        ], $headers);

        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 3],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 3000],
            ],
        ], $headers)->assertCreated();

        $saleId = $saleResponse->json('data.sale.id');
        $saleItemId = $saleResponse->json('data.sale.items.0.id');

        $this->postJson("/api/v1/sales/{$saleId}/returns", [
            'reason' => 'wrong_item',
            'items' => [
                ['sale_item_id' => $saleItemId, 'quantity' => 5],
            ],
        ], $headers)->assertUnprocessable()
            ->assertJsonValidationErrors(['items.0.quantity']);

        $this->assertDatabaseCount('sale_returns', 0);
    }

    public function test_double_return_prevented_after_full_return(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
            'unit_cost' => 500,
        ], $headers);

        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 2000],
            ],
        ], $headers)->assertCreated();

        $saleId = $saleResponse->json('data.sale.id');
        $saleItemId = $saleResponse->json('data.sale.items.0.id');

        $this->postJson("/api/v1/sales/{$saleId}/returns", [
            'reason' => 'customer_changed_mind',
            'items' => [
                ['sale_item_id' => $saleItemId, 'quantity' => 2],
            ],
        ], $headers)->assertCreated();

        $this->postJson("/api/v1/sales/{$saleId}/returns", [
            'reason' => 'other',
            'items' => [
                ['sale_item_id' => $saleItemId, 'quantity' => 1],
            ],
        ], $headers)->assertUnprocessable()
            ->assertJsonValidationErrors(['items.0.quantity']);

        $this->assertDatabaseCount('sale_returns', 1);
    }

    public function test_return_of_nonexistent_sale_item_rejected(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
            'unit_cost' => 500,
        ], $headers);

        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 1000],
            ],
        ], $headers)->assertCreated();

        $saleId = $saleResponse->json('data.sale.id');

        $this->postJson("/api/v1/sales/{$saleId}/returns", [
            'reason' => 'other',
            'items' => [
                ['sale_item_id' => '00000000-0000-4000-8000-000000000099', 'quantity' => 1],
            ],
        ], $headers)->assertUnprocessable();
    }

    public function test_credit_refund_updates_customer_ledger(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $customer = $this->fixture['customer'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 20,
            'unit_cost' => 500,
        ], $headers);

        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'customer_id' => $customer->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 2000],
            ],
        ], $headers)->assertCreated();

        $saleId = $saleResponse->json('data.sale.id');
        $saleItemId = $saleResponse->json('data.sale.items.0.id');

        $this->postJson("/api/v1/sales/{$saleId}/returns", [
            'reason' => 'defective',
            'refund_method' => 'credit',
            'items' => [
                ['sale_item_id' => $saleItemId, 'quantity' => 1],
            ],
        ], $headers)->assertCreated();

        $this->assertDatabaseHas('customer_transactions', [
            'customer_id' => $customer->id,
            'sale_id' => $saleId,
            'transaction_type' => 'SALE_RETURN',
            'amount' => 1000,
        ]);
    }

    public function test_return_idempotency_returns_existing(): void
    {
        $headers = array_merge(
            $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']),
            ['Idempotency-Key' => 'return-key-001'],
        );

        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
            'unit_cost' => 500,
        ], $headers);

        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 2000],
            ],
        ], $headers)->assertCreated();

        $saleId = $saleResponse->json('data.sale.id');
        $saleItemId = $saleResponse->json('data.sale.items.0.id');

        $first = $this->postJson("/api/v1/sales/{$saleId}/returns", [
            'reason' => 'other',
            'items' => [
                ['sale_item_id' => $saleItemId, 'quantity' => 1],
            ],
        ], $headers)->assertCreated();

        $second = $this->postJson("/api/v1/sales/{$saleId}/returns", [
            'reason' => 'other',
            'items' => [
                ['sale_item_id' => $saleItemId, 'quantity' => 1],
            ],
        ], $headers)->assertCreated();

        $this->assertSame(
            $first->json('data.sale_return.id'),
            $second->json('data.sale_return.id'),
        );
        $this->assertDatabaseCount('sale_returns', 1);
    }
}
