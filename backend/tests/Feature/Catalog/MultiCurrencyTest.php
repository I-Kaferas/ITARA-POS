<?php

namespace Tests\Feature\Catalog;

use App\Models\Currency;
use App\Models\CurrencyExchangeRate;
use App\Models\Price;
use App\Models\SalePayment;
use App\Services\Catalog\CurrencyConverter;
use App\Services\Catalog\PriceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class MultiCurrencyTest extends TestCase
{
    use InteractsWithTenants, RefreshDatabase;

    private array $fixture;

    private array $headers;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('fx', 'fx@test.local');
        $this->headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
    }

    public function test_primary_and_secondary_currencies_with_rate_history(): void
    {
        $usd = $this->postJson('/api/v1/currencies', [
            'code' => 'USD',
            'name' => 'US Dollar',
            'symbol' => '$',
            'decimal_places' => 2,
            'exchange_rate' => 2900,
            'is_default' => false,
            'is_active' => true,
        ], $this->headers)->assertCreated()->json('data');

        $this->assertSame('secondary', $usd['role']);
        $this->assertDatabaseCount('currency_exchange_rates', 1);

        $this->patchJson("/api/v1/currencies/{$usd['id']}", [
            'exchange_rate' => 3000,
            'note' => 'Market open',
        ], $this->headers)->assertOk();

        $history = $this->getJson("/api/v1/currencies/{$usd['id']}/rates", $this->headers)
            ->assertOk()
            ->json('data');

        $this->assertCount(2, $history);
        $this->assertEquals(3000, (float) $history[0]['rate']);
        $this->assertEquals(2900, (float) $history[0]['previous_rate']);

        $this->postJson("/api/v1/currencies/{$usd['id']}/rates", [
            'rate' => 3050,
            'note' => 'Midday',
        ], $this->headers)->assertCreated();

        $this->assertEquals(3050, (float) Currency::query()->find($usd['id'])->exchange_rate);
        $this->assertDatabaseCount('currency_exchange_rates', 3);
    }

    public function test_primary_currency_rate_must_remain_one(): void
    {
        $primary = Currency::query()->where('is_default', true)->firstOrFail();

        $this->patchJson("/api/v1/currencies/{$primary->id}", [
            'exchange_rate' => 2,
        ], $this->headers)->assertStatus(422);
    }

    public function test_convert_endpoint_and_converter(): void
    {
        $this->postJson('/api/v1/currencies', [
            'code' => 'USD',
            'name' => 'US Dollar',
            'symbol' => '$',
            'decimal_places' => 2,
            'exchange_rate' => 2900,
            'is_active' => true,
        ], $this->headers)->assertCreated();

        $this->getJson('/api/v1/currencies/convert?amount=100&from=USD&to=FBU', $this->headers)
            ->assertOk()
            ->assertJsonPath('data.converted', 2900);

        $converter = app(CurrencyConverter::class);
        $this->assertSame(100, $converter->convert(2900, 'FBU', 'USD'));
    }

    public function test_prices_prefer_native_currency_tier(): void
    {
        $this->postJson('/api/v1/currencies', [
            'code' => 'USD',
            'name' => 'US Dollar',
            'symbol' => '$',
            'decimal_places' => 2,
            'exchange_rate' => 2900,
            'is_active' => true,
        ], $this->headers)->assertCreated();

        $product = $this->fixture['product'];

        Price::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'priceable_type' => $product->getMorphClass(),
            'priceable_id' => $product->id,
            'price_type' => 'retail',
            'amount' => 290000,
            'currency_code' => 'FBU',
            'min_quantity' => 1,
            'is_active' => true,
        ]);

        Price::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'priceable_type' => $product->getMorphClass(),
            'priceable_id' => $product->id,
            'price_type' => 'retail',
            'amount' => 9999,
            'currency_code' => 'USD',
            'min_quantity' => 1,
            'is_active' => true,
        ]);

        $product->unsetRelation('prices');

        $resolved = app(PriceService::class)->resolve($product, null, 'retail', 1, null, 'USD');

        $this->assertSame(9999, $resolved->amount);
        $this->assertSame('USD', $resolved->currencyCode);
    }

    public function test_cart_calculates_in_secondary_currency(): void
    {
        $this->postJson('/api/v1/currencies', [
            'code' => 'USD',
            'name' => 'US Dollar',
            'symbol' => '$',
            'decimal_places' => 2,
            'exchange_rate' => 1000,
            'is_active' => true,
        ], $this->headers)->assertCreated();

        $store = $this->fixture['store'];
        $product = $this->fixture['product'];
        $product->update(['base_price' => 5000]);
        $product->importToStore($store);

        $cart = $this->postJson("/api/v1/stores/{$store->id}/cart/calculate", [
            'currency' => 'USD',
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
        ], $this->headers)->assertOk()->json('data');

        // 5000 FBU ÷ 1000 = 5.00 USD → 500 minor units
        $this->assertSame('USD', $cart['currency']);
        $this->assertSame(500, $cart['grand_total']);
    }

    public function test_sale_accepts_multi_currency_payment(): void
    {
        $this->postJson('/api/v1/currencies', [
            'code' => 'USD',
            'name' => 'US Dollar',
            'symbol' => '$',
            'decimal_places' => 2,
            'exchange_rate' => 2900,
            'is_active' => true,
        ], $this->headers)->assertCreated();

        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $product->update(['base_price' => 2900]);
        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
            'unit_cost' => 1000,
        ], $this->headers)->assertCreated();

        $sale = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'customer_id' => $this->fixture['customer']->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 100, 'currency' => 'USD'],
            ],
        ], $this->headers)->assertCreated()->json('data.sale');

        $this->assertSame('FBU', $sale['currency']);
        $this->assertSame(2900, $sale['total']);
        $this->assertSame(2900, $sale['paid_amount']);

        $payment = SalePayment::query()->where('sale_id', $sale['id'])->first();
        $this->assertNotNull($payment);
        $this->assertSame('USD', $payment->currency);
        $this->assertSame(100, $payment->amount);
        $this->assertSame(2900, $payment->amount_in_sale_currency);
        $this->assertSame('FBU', $payment->sale_currency);
        $this->assertEquals(2900.0, (float) $payment->exchange_rate);
    }

    public function test_rate_history_rows_are_tenant_scoped(): void
    {
        $this->postJson('/api/v1/currencies', [
            'code' => 'EUR',
            'name' => 'Euro',
            'symbol' => '€',
            'decimal_places' => 2,
            'exchange_rate' => 3200,
            'is_active' => true,
        ], $this->headers)->assertCreated();

        $other = $this->createTenantFixture('fx-b', 'fx-b@test.local');
        $otherHeaders = $this->tenantHeaders($other['token'], $other['tenant']);

        $this->assertSame(
            1,
            CurrencyExchangeRate::query()->withoutGlobalScopes()->where('tenant_id', $this->fixture['tenant']->id)->count()
        );
        $this->assertSame(
            0,
            CurrencyExchangeRate::query()->withoutGlobalScopes()->where('tenant_id', $other['tenant']->id)->count()
        );

        $this->getJson('/api/v1/currencies?active_only=1', $otherHeaders)
            ->assertOk()
            ->assertJsonMissing(['code' => 'EUR']);
    }
}
