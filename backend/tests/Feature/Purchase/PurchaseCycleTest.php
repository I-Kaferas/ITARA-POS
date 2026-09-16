<?php

namespace Tests\Feature\Purchase;

use App\Enums\PurchaseOrderStatus;
use App\Enums\PurchaseProformaStatus;
use App\Enums\PurchaseRequisitionStatus;
use App\Models\PurchaseOrder;
use App\Models\PurchaseProforma;
use App\Models\PurchaseRequisition;
use App\Models\StockBalance;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PurchaseCycleTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('pcyc', 'pcyc@test.local');
    }

    public function test_purchase_cycle_tables_exist(): void
    {
        $this->assertTrue(Schema::hasTable('purchase_requisitions'));
        $this->assertTrue(Schema::hasTable('purchase_requisition_items'));
        $this->assertTrue(Schema::hasTable('purchase_proformas'));
        $this->assertTrue(Schema::hasTable('purchase_proforma_items'));
        $this->assertTrue(Schema::hasColumn('purchase_orders', 'purchase_requisition_id'));
        $this->assertTrue(Schema::hasColumn('purchase_orders', 'purchase_proforma_id'));
    }

    public function test_requisition_to_proforma_to_order_to_receipt(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $supplier = $this->fixture['supplier'];
        $product = $this->fixture['product'];

        $create = $this->postJson('/api/v1/purchase-requisitions', [
            'warehouse_id' => $warehouse->id,
            'supplier_id' => $supplier->id,
            'priority' => 'high',
            'department' => 'Kitchen',
            'reason' => 'Restock rice',
            'items' => [
                ['product_id' => $product->id, 'quantity' => 8, 'unit_cost' => 400],
            ],
        ], $headers)->assertCreated();

        $reqId = $create->json('data.id');
        $this->assertSame('draft', $create->json('data.status'));
        $this->assertSame(3200, $create->json('data.total'));

        $this->postJson("/api/v1/purchase-requisitions/{$reqId}/convert", [
            'target' => 'proforma',
        ], $headers)->assertStatus(422);

        $this->postJson("/api/v1/purchase-requisitions/{$reqId}/act", [
            'action' => 'submit',
        ], $headers)->assertOk()->assertJsonPath('data.status', PurchaseRequisitionStatus::Submitted->value);

        $this->postJson("/api/v1/purchase-requisitions/{$reqId}/act", [
            'action' => 'approve',
        ], $headers)->assertOk()->assertJsonPath('data.status', PurchaseRequisitionStatus::Approved->value);

        $converted = $this->postJson("/api/v1/purchase-requisitions/{$reqId}/convert", [
            'target' => 'proforma',
        ], $headers)->assertCreated();

        $this->assertSame('proforma', $converted->json('data.type'));
        $pfId = $converted->json('data.id');
        $this->assertSame(PurchaseRequisitionStatus::Converted->value, PurchaseRequisition::find($reqId)->status->value);

        $this->postJson("/api/v1/purchase-proformas/{$pfId}/act", ['action' => 'send'], $headers)
            ->assertOk()->assertJsonPath('data.status', PurchaseProformaStatus::Sent->value);
        $this->postJson("/api/v1/purchase-proformas/{$pfId}/act", ['action' => 'review'], $headers)
            ->assertOk()->assertJsonPath('data.status', PurchaseProformaStatus::UnderReview->value);
        $this->postJson("/api/v1/purchase-proformas/{$pfId}/act", ['action' => 'approve'], $headers)
            ->assertOk()->assertJsonPath('data.status', PurchaseProformaStatus::Approved->value);

        $poConvert = $this->postJson("/api/v1/purchase-proformas/{$pfId}/convert", [
            'warehouse_id' => $warehouse->id,
        ], $headers)->assertCreated();

        $poId = $poConvert->json('data.id');
        $order = PurchaseOrder::with('items')->findOrFail($poId);
        $this->assertSame($reqId, $order->purchase_requisition_id);
        $this->assertSame($pfId, $order->purchase_proforma_id);
        $this->assertSame(PurchaseOrderStatus::Approved->value, $order->status->value);
        $this->assertSame(8, $order->items->first()->quantity_ordered);
        $this->assertSame(PurchaseProformaStatus::Converted->value, PurchaseProforma::find($pfId)->status->value);

        $this->postJson("/api/v1/purchase-orders/{$poId}/receive", [
            'items' => [
                ['purchase_order_item_id' => $order->items->first()->id, 'quantity' => 8],
            ],
        ], $headers)->assertCreated();

        $balance = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->first();

        $this->assertNotNull($balance);
        $this->assertSame(8, $balance->quantity_on_hand);
        $this->assertSame(PurchaseOrderStatus::Received->value, PurchaseOrder::find($poId)->status->value);
    }

    public function test_approved_requisition_can_convert_directly_to_purchase_order(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $create = $this->postJson('/api/v1/purchase-requisitions', [
            'warehouse_id' => $this->fixture['warehouse']->id,
            'items' => [
                ['product_id' => $this->fixture['product']->id, 'quantity' => 3, 'unit_cost' => 1000],
            ],
        ], $headers)->assertCreated();

        $reqId = $create->json('data.id');
        $this->postJson("/api/v1/purchase-requisitions/{$reqId}/act", ['action' => 'submit'], $headers);
        $this->postJson("/api/v1/purchase-requisitions/{$reqId}/act", ['action' => 'approve'], $headers);

        $converted = $this->postJson("/api/v1/purchase-requisitions/{$reqId}/convert", [
            'target' => 'purchase_order',
            'supplier_id' => $this->fixture['supplier']->id,
            'warehouse_id' => $this->fixture['warehouse']->id,
        ], $headers)->assertCreated();

        $this->assertSame('purchase_order', $converted->json('data.type'));
        $order = PurchaseOrder::findOrFail($converted->json('data.id'));
        $this->assertSame($reqId, $order->purchase_requisition_id);
        $this->assertNull($order->purchase_proforma_id);
        $this->assertSame($this->fixture['supplier']->id, $order->supplier_id);
        $this->assertSame(PurchaseOrderStatus::Approved->value, $order->status->value);

        $this->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['purchase_order_item_id' => $order->items()->first()->id, 'quantity' => 3],
            ],
        ], $headers)->assertCreated();

        $balance = StockBalance::query()
            ->where('warehouse_id', $this->fixture['warehouse']->id)
            ->where('product_id', $this->fixture['product']->id)
            ->first();

        $this->assertNotNull($balance);
        $this->assertSame(3, $balance->quantity_on_hand);
    }

    public function test_overview_includes_pending_cycle_kpis(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->postJson('/api/v1/purchase-requisitions', [
            'warehouse_id' => $this->fixture['warehouse']->id,
            'items' => [
                ['product_id' => $this->fixture['product']->id, 'quantity' => 1, 'unit_cost' => 100],
            ],
        ], $headers)->assertCreated();

        $this->postJson('/api/v1/purchase-proformas', [
            'supplier_id' => $this->fixture['supplier']->id,
            'warehouse_id' => $this->fixture['warehouse']->id,
            'items' => [
                ['product_id' => $this->fixture['product']->id, 'quantity' => 2, 'unit_cost' => 250],
            ],
        ], $headers)->assertCreated();

        $this->getJson('/api/v1/purchases/overview', $headers)
            ->assertOk()
            ->assertJsonPath('data.pending_requisitions', 1)
            ->assertJsonPath('data.pending_proformas', 1)
            ->assertJsonPath('data.returns_total', 0);
    }
}
