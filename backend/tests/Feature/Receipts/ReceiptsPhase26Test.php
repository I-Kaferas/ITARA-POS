<?php

namespace Tests\Feature\Receipts;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class ReceiptsPhase26Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('receipts26', 'receipts26@test.local');
    }

    public function test_phase26_receipt_and_invoice_tables_exist(): void
    {
        foreach (['sale_receipts', 'sale_invoices'] as $table) {
            $this->assertTrue(Schema::hasTable($table), "Missing table: {$table}");
        }
    }

    public function test_receipt_payload_contains_required_fields(): void
    {
        $saleId = $this->createCompletedSale();
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $response = $this->getJson("/api/v1/sales/{$saleId}/receipt?format=thermal_80", $headers)
            ->assertOk();

        $data = $response->json('data');

        $this->assertSame('receipt', $data['document_type']);
        $this->assertSame('thermal_80', $data['format']);
        $this->assertArrayHasKey('company', $data);
        $this->assertArrayHasKey('branch', $data);
        $this->assertArrayHasKey('sale_reference', $data);
        $this->assertArrayHasKey('date', $data);
        $this->assertArrayHasKey('cashier', $data);
        $this->assertArrayHasKey('items', $data);
        $this->assertNotEmpty($data['items']);
        $this->assertArrayHasKey('quantity', $data['items'][0]);
        $this->assertArrayHasKey('unit_price', $data['items'][0]);
        $this->assertArrayHasKey('line_discount', $data['items'][0]);
        $this->assertArrayHasKey('line_tax', $data['items'][0]);
        $this->assertArrayHasKey('discount_total', $data);
        $this->assertArrayHasKey('tax_total', $data);
        $this->assertArrayHasKey('total', $data);
        $this->assertArrayHasKey('payments', $data);
        $this->assertArrayHasKey('change', $data);
    }

    public function test_issue_receipt_creates_numbered_record(): void
    {
        $saleId = $this->createCompletedSale();
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $response = $this->postJson("/api/v1/sales/{$saleId}/receipt", [
            'format' => 'thermal_58',
        ], $headers)->assertCreated();

        $response->assertJsonPath('data.receipt.format', 'thermal_58');
        $this->assertStringStartsWith('REC-', $response->json('data.receipt.receipt_number'));
        $this->assertSame('REC-000001', $response->json('data.receipt.receipt_number'));
        $this->assertSame('REC-000001', $response->json('data.payload.receipt_number'));
        $this->assertSame('thermal_58', $response->json('data.payload.format'));

        $this->assertDatabaseHas('sale_receipts', [
            'sale_id' => $saleId,
            'receipt_number' => 'REC-000001',
            'format' => 'thermal_58',
        ]);
    }

    public function test_receipt_reprint_increments_counter(): void
    {
        $saleId = $this->createCompletedSale();
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->postJson("/api/v1/sales/{$saleId}/receipt", [
            'format' => 'thermal_80',
        ], $headers)->assertCreated();

        $this->postJson("/api/v1/sales/{$saleId}/receipt", [
            'format' => 'thermal_80',
            'reprint' => true,
        ], $headers)->assertCreated()
            ->assertJsonPath('data.receipt.reprint_count', 1);

        $this->assertDatabaseCount('sale_receipts', 1);
    }

    public function test_issue_invoice_creates_numbered_record(): void
    {
        $saleId = $this->createCompletedSale();
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $response = $this->postJson("/api/v1/sales/{$saleId}/invoice", [
            'format' => 'a4',
        ], $headers)->assertCreated();

        $response->assertJsonPath('data.invoice.format', 'a4');
        $response->assertJsonPath('data.invoice.status', 'issued');
        $this->assertSame('INV-000001', $response->json('data.invoice.invoice_number'));
        $this->assertSame('invoice', $response->json('data.payload.document_type'));
        $this->assertSame('INV-000001', $response->json('data.payload.invoice_number'));

        $this->assertDatabaseHas('sale_invoices', [
            'sale_id' => $saleId,
            'invoice_number' => 'INV-000001',
            'status' => 'issued',
        ]);
    }

    public function test_invoice_cancel(): void
    {
        $saleId = $this->createCompletedSale();
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $created = $this->postJson("/api/v1/sales/{$saleId}/invoice", [
            'format' => 'pdf',
        ], $headers)->assertCreated();

        $invoiceId = $created->json('data.invoice.id');

        $this->postJson("/api/v1/sale-invoices/{$invoiceId}/cancel", [], $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');
    }

    public function test_list_receipts_and_invoices_for_sale(): void
    {
        $saleId = $this->createCompletedSale();
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->postJson("/api/v1/sales/{$saleId}/receipt", ['format' => 'thermal_80'], $headers);
        $this->postJson("/api/v1/sales/{$saleId}/invoice", ['format' => 'a4'], $headers);

        $this->getJson("/api/v1/sales/{$saleId}/receipts", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->getJson("/api/v1/sales/{$saleId}/invoices", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_receipt_formats_endpoint(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->getJson('/api/v1/receipt-formats', $headers)
            ->assertOk()
            ->assertJsonCount(4, 'data')
            ->assertJsonFragment(['value' => 'thermal_58'])
            ->assertJsonFragment(['value' => 'thermal_80'])
            ->assertJsonFragment(['value' => 'a4'])
            ->assertJsonFragment(['value' => 'pdf']);
    }

    public function test_cash_payment_change_in_receipt_payload(): void
    {
        $saleId = $this->createCompletedSale(tendered: 2500, amount: 2000);
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->postJson("/api/v1/sales/{$saleId}/receipt", ['format' => 'thermal_80'], $headers);

        $response = $this->getJson("/api/v1/sales/{$saleId}/receipt", $headers)->assertOk();

        $this->assertSame(500, $response->json('data.change'));
        $this->assertSame(2500, $response->json('data.payments.0.tendered'));
        $this->assertSame(500, $response->json('data.payments.0.change'));
    }

    private function createCompletedSale(int $quantity = 2, int $amount = 2000, ?int $tendered = null): string
    {
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

        $payment = [
            'method' => 'cash',
            'amount' => $amount,
        ];

        if ($tendered !== null) {
            $payment['metadata'] = ['tendered' => $tendered];
        }

        $response = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'customer_id' => $this->fixture['customer']->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => $quantity],
            ],
            'payments' => [$payment],
        ], $headers)->assertCreated();

        return $response->json('data.sale.id');
    }
}
