<?php

namespace Tests\Feature\Purchase;

use App\Enums\InventoryMovementType;
use App\Enums\PurchaseOrderStatus;
use App\Models\AccountingEntry;
use App\Models\AuditLog;
use App\Models\GoodsReceipt;
use App\Models\InventoryMovement;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseOrder;
use App\Models\StockBalance;
use App\Models\SupplierTransaction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PurchasePhase14Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('pur14', 'pur14@test.local');
    }

    public function test_phase14_purchase_tables_exist(): void
    {
        $this->assertTrue(Schema::hasTable('purchase_orders'));
        $this->assertTrue(Schema::hasTable('purchase_order_items'));
        $this->assertTrue(Schema::hasTable('goods_receipts'));
        $this->assertTrue(Schema::hasTable('goods_receipt_items'));
        $this->assertTrue(Schema::hasTable('purchase_invoices'));
        $this->assertTrue(Schema::hasTable('purchase_payments'));
        $this->assertTrue(Schema::hasTable('accounting_entries'));
        $this->assertTrue(Schema::hasTable('audit_logs'));
        $this->assertFalse(Schema::hasTable('purchases'));
    }

    public function test_purchase_order_workflow_and_receive_updates_stock(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $supplier = $this->fixture['supplier'];
        $product = $this->fixture['product'];

        $create = $this->postJson('/api/v1/purchase-orders', [
            'warehouse_id' => $warehouse->id,
            'supplier_id' => $supplier->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 10, 'unit_cost' => 500],
            ],
        ], $headers)->assertCreated();

        $poId = $create->json('data.id');
        $itemId = $create->json('data.items.0.id');

        $this->assertSame('draft', $create->json('data.status'));

        $this->postJson("/api/v1/purchase-orders/{$poId}/submit", [], $headers)->assertOk()
            ->assertJsonPath('data.status', PurchaseOrderStatus::Pending->value);

        $this->postJson("/api/v1/purchase-orders/{$poId}/approve", [], $headers)->assertOk()
            ->assertJsonPath('data.status', PurchaseOrderStatus::Approved->value);

        $receive = $this->postJson("/api/v1/purchase-orders/{$poId}/receive", [
            'items' => [
                ['purchase_order_item_id' => $itemId, 'quantity' => 6],
            ],
        ], $headers)->assertCreated();

        $this->assertSame(PurchaseOrderStatus::PartiallyReceived->value, PurchaseOrder::find($poId)->status->value);

        $this->postJson("/api/v1/purchase-orders/{$poId}/receive", [
            'items' => [
                ['purchase_order_item_id' => $itemId, 'quantity' => 4],
            ],
        ], $headers)->assertCreated();

        $po = PurchaseOrder::with('items')->find($poId);
        $this->assertSame(PurchaseOrderStatus::Received->value, $po->status->value);
        $this->assertSame(10, $po->items->first()->quantity_received);

        $balance = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->first();

        $this->assertNotNull($balance);
        $this->assertSame(10, $balance->quantity_on_hand);

        $this->assertSame(
            2,
            InventoryMovement::query()
                ->where('product_id', $product->id)
                ->where('movement_type', InventoryMovementType::Purchase)
                ->count()
        );

        $this->assertSame(2, GoodsReceipt::query()->where('purchase_order_id', $poId)->count());
        $this->assertSame(2, PurchaseInvoice::query()->where('purchase_order_id', $poId)->count());
        $this->assertSame(2, SupplierTransaction::query()->where('purchase_order_id', $poId)->count());
        $this->assertSame(4, AccountingEntry::query()->count());
        $this->assertGreaterThanOrEqual(2, AuditLog::query()->count());
    }

    public function test_purchase_payment_completes_order(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $create = $this->postJson('/api/v1/purchase-orders', [
            'warehouse_id' => $this->fixture['warehouse']->id,
            'supplier_id' => $this->fixture['supplier']->id,
            'items' => [
                ['product_id' => $this->fixture['product']->id, 'quantity' => 5, 'unit_cost' => 1000],
            ],
        ], $headers)->assertCreated();

        $poId = $create->json('data.id');
        $itemId = $create->json('data.items.0.id');

        $this->postJson("/api/v1/purchase-orders/{$poId}/submit", [], $headers);
        $this->postJson("/api/v1/purchase-orders/{$poId}/approve", [], $headers);
        $this->postJson("/api/v1/purchase-orders/{$poId}/receive", [
            'items' => [['purchase_order_item_id' => $itemId, 'quantity' => 5]],
        ], $headers);

        $invoice = PurchaseInvoice::query()->where('purchase_order_id', $poId)->firstOrFail();

        $this->postJson("/api/v1/purchase-invoices/{$invoice->id}/payments", [
            'amount' => $invoice->total,
        ], $headers)->assertCreated();

        $invoice->refresh();
        $this->assertSame('paid', $invoice->status->value);

        $po = PurchaseOrder::find($poId);
        $this->assertSame(PurchaseOrderStatus::Completed->value, $po->status->value);
    }

    public function test_cannot_receive_unapproved_order(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $create = $this->postJson('/api/v1/purchase-orders', [
            'warehouse_id' => $this->fixture['warehouse']->id,
            'supplier_id' => $this->fixture['supplier']->id,
            'items' => [
                ['product_id' => $this->fixture['product']->id, 'quantity' => 1, 'unit_cost' => 100],
            ],
        ], $headers)->assertCreated();

        $poId = $create->json('data.id');
        $itemId = $create->json('data.items.0.id');

        $this->postJson("/api/v1/purchase-orders/{$poId}/receive", [
            'items' => [['purchase_order_item_id' => $itemId, 'quantity' => 1]],
        ], $headers)->assertStatus(422);
    }

    public function test_zero_cost_receipt_without_supplier_updates_stock(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $create = $this->postJson('/api/v1/purchase-orders', [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 8, 'unit_cost' => 0],
            ],
        ], $headers)->assertCreated();

        $poId = $create->json('data.id');
        $itemId = $create->json('data.items.0.id');

        $this->postJson("/api/v1/purchase-orders/{$poId}/submit", [], $headers)->assertOk();
        $this->postJson("/api/v1/purchase-orders/{$poId}/approve", [], $headers)->assertOk();

        $this->postJson("/api/v1/purchase-orders/{$poId}/receive", [
            'items' => [
                ['purchase_order_item_id' => $itemId, 'quantity' => 8],
            ],
        ], $headers)->assertCreated();

        $po = PurchaseOrder::with('items')->find($poId);
        $this->assertSame(PurchaseOrderStatus::Received->value, $po->status->value);
        $this->assertSame(8, $po->items->first()->quantity_received);

        $balance = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->first();

        $this->assertNotNull($balance);
        $this->assertSame(8, $balance->quantity_on_hand);
        $this->assertSame(0, PurchaseInvoice::query()->where('purchase_order_id', $poId)->count());
        $this->assertSame(0, SupplierTransaction::query()->where('purchase_order_id', $poId)->count());
    }

    public function test_purchase_order_statuses_endpoint(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->getJson('/api/v1/purchase-orders/statuses', $headers)
            ->assertOk()
            ->assertJsonFragment(['draft'])
            ->assertJsonFragment(['completed']);
    }
}
