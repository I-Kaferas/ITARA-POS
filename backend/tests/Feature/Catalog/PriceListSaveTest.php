<?php

namespace Tests\Feature\Catalog;

use App\Models\Price;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PriceListSaveTest extends TestCase
{
    use InteractsWithTenants, RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('pricelist', 'pricelist@test.local');
    }

    public function test_price_list_save_keeps_distinct_tiers_when_ui_reuses_fallback_price_id(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $productId = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'PRICE-LIST-01',
            'name' => 'Produit prix',
            'product_type' => 'simple',
            'base_price' => 10000,
            'prices' => [
                ['price_type' => 'retail', 'amount' => 10000, 'currency_code' => 'FBU', 'min_quantity' => 1, 'is_active' => true],
            ],
        ], $headers)->assertCreated()->json('data.id');

        $list = $this->getJson("/api/v1/catalogs/{$catalog->id}/price-list", $headers)->assertOk();
        $row = collect($list->json('data'))->firstWhere('id', $productId);
        $this->assertNotNull($row);

        // Bug reproduction: wholesale/vip/special resolve via retail fallback and share retail price_id.
        $retailId = $row['prices']['retail']['price_id'] ?? null;
        $this->assertNotNull($retailId);

        $this->patchJson("/api/v1/products/{$productId}", [
            'prices' => [
                ['id' => $retailId, 'price_type' => 'retail', 'amount' => 11000, 'currency_code' => 'FBU', 'min_quantity' => 1, 'is_active' => true],
                ['id' => $retailId, 'price_type' => 'wholesale', 'amount' => 9000, 'currency_code' => 'FBU', 'min_quantity' => 1, 'is_active' => true],
                ['id' => $retailId, 'price_type' => 'vip', 'amount' => 8000, 'currency_code' => 'FBU', 'min_quantity' => 1, 'is_active' => true],
                ['id' => $retailId, 'price_type' => 'special', 'amount' => 7000, 'currency_code' => 'FBU', 'min_quantity' => 1, 'is_active' => true],
            ],
        ], $headers)->assertOk();

        $prices = Price::query()->where('priceable_id', $productId)->orderBy('price_type')->get();
        $this->assertCount(4, $prices);
        $this->assertSame(11000, (int) $prices->firstWhere('price_type', 'retail')?->amount);
        $this->assertSame(9000, (int) $prices->firstWhere('price_type', 'wholesale')?->amount);
        $this->assertSame(8000, (int) $prices->firstWhere('price_type', 'vip')?->amount);
        $this->assertSame(7000, (int) $prices->firstWhere('price_type', 'special')?->amount);

        $reload = $this->getJson("/api/v1/catalogs/{$catalog->id}/price-list", $headers)->assertOk();
        $saved = collect($reload->json('data'))->firstWhere('id', $productId);
        $this->assertSame(11000, $saved['prices']['retail']['amount']);
        $this->assertSame(9000, $saved['prices']['wholesale']['amount']);
        $this->assertSame(8000, $saved['prices']['vip']['amount']);
        $this->assertSame(7000, $saved['prices']['special']['amount']);
        $this->assertNotSame(
            $saved['prices']['retail']['price_id'],
            $saved['prices']['wholesale']['price_id'],
        );
        $this->assertSame('wholesale', $saved['prices']['wholesale']['resolved_type']);
    }

    public function test_price_list_exposes_null_price_id_for_fallback_tiers(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $productId = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'PRICE-LIST-02',
            'name' => 'Produit fallback',
            'product_type' => 'simple',
            'base_price' => 5000,
            'prices' => [
                ['price_type' => 'retail', 'amount' => 5000, 'currency_code' => 'FBU', 'min_quantity' => 1, 'is_active' => true],
            ],
        ], $headers)->assertCreated()->json('data.id');

        $row = collect(
            $this->getJson("/api/v1/catalogs/{$catalog->id}/price-list", $headers)->assertOk()->json('data')
        )->firstWhere('id', $productId);

        $this->assertNotNull($row['prices']['retail']['price_id']);
        $this->assertNull($row['prices']['wholesale']['price_id']);
        $this->assertNull($row['prices']['vip']['price_id']);
        $this->assertNull($row['prices']['special']['price_id']);
        $this->assertSame('retail', $row['prices']['wholesale']['resolved_type']);
    }
}
