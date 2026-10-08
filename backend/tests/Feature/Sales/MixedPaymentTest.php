<?php

namespace Tests\Feature\Sales;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class MixedPaymentTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('mixedpay', 'mixedpay@test.local');
    }

    public function test_sale_accepts_multiple_payment_methods(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 100,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $unitPrice = 100000;

        $response = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => $unitPrice],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 40000],
                ['method' => 'mobile_money', 'amount' => 30000],
                ['method' => 'card', 'amount' => 20000],
                ['method' => 'bank_transfer', 'amount' => 10000],
            ],
        ], $headers)->assertCreated();

        $response->assertJsonPath('data.sale.total', 100000);
        $response->assertJsonPath('data.sale.paid_amount', 100000);
        $response->assertJsonPath('data.sale.payment_status', 'paid');
        $response->assertJsonPath('data.payment.is_mixed', true);

        $saleId = $response->json('data.sale.id');

        foreach (['cash' => 40000, 'mobile_money' => 30000, 'card' => 20000, 'bank_transfer' => 10000] as $method => $amount) {
            $this->assertDatabaseHas('sale_payments', [
                'sale_id' => $saleId,
                'payment_method' => $method,
                'amount' => $amount,
            ]);
        }
    }

    public function test_payment_methods_catalog_includes_required_tenders(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];

        $response = $this->getJson(
            "/api/v1/payments/methods?store_id={$store->id}&pos_only=1",
            $headers
        )->assertOk();

        $codes = collect($response->json('data'))->pluck('value')->all();

        foreach (['cash', 'mobile_money', 'card', 'bank_transfer', 'credit'] as $code) {
            $this->assertContains($code, $codes);
        }
    }

    public function test_rejects_unknown_payment_method(): void
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
        ], $headers)->assertCreated();

        $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'unit_price' => 1000],
            ],
            'payments' => [
                ['method' => 'bitcoin', 'amount' => 1000],
            ],
        ], $headers)->assertStatus(422);
    }
}
