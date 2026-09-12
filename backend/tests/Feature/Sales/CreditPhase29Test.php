<?php

namespace Tests\Feature\Sales;

use App\Models\CustomerTransaction;
use App\Models\Sale;
use App\Models\SaleInstallment;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class CreditPhase29Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('credit29', 'credit29@test.local');
    }

    public function test_phase29_schema_exists(): void
    {
        $this->assertTrue(Schema::hasColumn('sales', 'paid_amount'));
        $this->assertTrue(Schema::hasColumn('sales', 'due_date'));
        $this->assertTrue(Schema::hasColumn('sales', 'payment_status'));
        $this->assertTrue(Schema::hasTable('sale_installments'));
    }

    public function test_partial_payment_credit_sale_example(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $customer = $this->fixture['customer'];

        $customer->update([
            'credit_limit' => 1000000,
            'payment_terms_days' => 30,
        ]);

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 100,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $unitPrice = 500000;

        $response = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'customer_id' => $customer->id,
            'due_date' => '2026-10-15',
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => $unitPrice],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 200000],
            ],
        ], $headers)->assertCreated();

        $response->assertJsonPath('data.sale.total', 500000);
        $response->assertJsonPath('data.sale.paid_amount', 200000);
        $response->assertJsonPath('data.sale.outstanding_amount', 300000);
        $response->assertJsonPath('data.sale.payment_status', 'partial');
        $response->assertJsonPath('data.sale.due_date', '2026-10-15');
        $response->assertJsonPath('data.sale.credit.paid_amount', 200000);
        $response->assertJsonPath('data.sale.credit.outstanding_amount', 300000);
        $response->assertJsonPath('data.payment.outstanding_amount', 300000);

        $saleId = $response->json('data.sale.id');

        $this->assertDatabaseHas('sales', [
            'id' => $saleId,
            'total' => 500000,
            'paid_amount' => 200000,
            'payment_status' => 'partial',
        ]);

        $this->assertDatabaseHas('sale_payments', [
            'sale_id' => $saleId,
            'payment_method' => 'cash',
            'amount' => 200000,
        ]);
        $this->assertDatabaseHas('sale_payments', [
            'sale_id' => $saleId,
            'payment_method' => 'credit',
            'amount' => 300000,
        ]);

        $this->assertDatabaseHas('customer_transactions', [
            'sale_id' => $saleId,
            'customer_id' => $customer->id,
            'amount' => 300000,
            'paid_amount' => 0,
        ]);
    }

    public function test_full_credit_sale(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $customer = $this->fixture['customer'];

        $customer->update(['credit_limit' => 1000000]);

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 50,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $response = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'customer_id' => $customer->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => 500000],
            ],
            'payments' => [
                ['method' => 'credit', 'amount' => 500000],
            ],
        ], $headers)->assertCreated();

        $response->assertJsonPath('data.sale.paid_amount', 0);
        $response->assertJsonPath('data.sale.outstanding_amount', 500000);
        $response->assertJsonPath('data.sale.payment_status', 'on_credit');
    }

    public function test_installment_plan_on_credit_sale(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $customer = $this->fixture['customer'];

        $customer->update(['credit_limit' => 1000000]);

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 50,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $response = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'customer_id' => $customer->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => 300000],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 100000],
            ],
            'installments' => [
                'count' => 3,
                'first_due_date' => '2026-10-01',
            ],
        ], $headers)->assertCreated();

        $saleId = $response->json('data.sale.id');

        $response->assertJsonCount(3, 'data.sale.installments');
        $response->assertJsonPath('data.sale.installments.0.amount', 66666);
        $response->assertJsonPath('data.sale.installments.2.amount', 66668);

        $this->assertSame(3, SaleInstallment::query()->where('sale_id', $saleId)->count());
    }

    public function test_customer_payment_updates_sale_balance(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $customer = $this->fixture['customer'];

        $customer->update(['credit_limit' => 1000000]);

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 50,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'customer_id' => $customer->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => 500000],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 200000],
            ],
        ], $headers)->assertCreated();

        $saleId = $saleResponse->json('data.sale.id');

        $this->postJson("/api/v1/customers/{$customer->id}/payments", [
            'amount' => 150000,
            'payment_method' => 'cash',
        ], $headers)->assertCreated();

        $sale = Sale::query()->findOrFail($saleId);
        $this->assertSame(350000, $sale->paid_amount);
        $this->assertSame(150000, $sale->outstandingAmount());
        $this->assertSame('partial', $sale->payment_status->value);

        $transaction = CustomerTransaction::query()
            ->where('sale_id', $saleId)
            ->firstOrFail();
        $this->assertSame(150000, $transaction->paid_amount);
    }

    public function test_partial_payment_without_customer_rejected(): void
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

        $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => 500000],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 200000],
            ],
        ], $headers)->assertStatus(422);
    }
}
