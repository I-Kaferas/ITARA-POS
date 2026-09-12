<?php

namespace Tests\Feature\Pos;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PosPhase16Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('pos16', 'pos16@test.local');
    }

    public function test_pos_catalog_endpoint_returns_products_and_categories(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];
        $store = $this->fixture['store'];

        $category = Category::create([
            'tenant_id' => $this->fixture['tenant']->id,
            'catalog_id' => $catalog->id,
            'name' => 'Boissons',
            'slug' => 'boissons',
            'sort_order' => 1,
            'is_active' => true,
        ]);

        $product = Product::create([
            'tenant_id' => $this->fixture['tenant']->id,
            'catalog_id' => $catalog->id,
            'category_id' => $category->id,
            'sku' => 'POS-DRINK-01',
            'name' => 'Eau minérale',
            'base_price' => 500,
            'is_active' => true,
        ]);

        $this->fixture['product']->importToStore($store);
        $product->importToStore($store);

        $response = $this->getJson("/api/v1/stores/{$store->id}/pos/catalog", $headers)
            ->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'store_id',
                    'products',
                    'categories',
                ],
            ]);

        $products = $response->json('data.products');
        $this->assertCount(2, $products);

        $drink = collect($products)->firstWhere('sku', 'POS-DRINK-01');
        $this->assertNotNull($drink);
        $this->assertSame($category->id, $drink['category_id']);
        $this->assertSame(500, $drink['price']);

        $categories = $response->json('data.categories');
        $this->assertNotEmpty($categories);
        $this->assertSame('Boissons', collect($categories)->firstWhere('id', $category->id)['name']);
    }

    public function test_pos_products_endpoint_returns_available_store_products_only(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];

        $this->fixture['product']->importToStore($store);

        $this->getJson("/api/v1/stores/{$store->id}/pos/products", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_pos_catalog_requires_sales_view_permission(): void
    {
        $store = $this->fixture['store'];

        $this->getJson("/api/v1/stores/{$store->id}/pos/catalog")
            ->assertUnauthorized();
    }
}
