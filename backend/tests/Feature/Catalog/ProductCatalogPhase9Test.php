<?php

namespace Tests\Feature\Catalog;

use App\Models\Brand;
use App\Models\Catalog;
use App\Models\Category;
use App\Models\Product;
use App\Models\Tax;
use App\Models\Unit;
use App\Services\Catalog\PosCatalogSyncService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class ProductCatalogPhase9Test extends TestCase
{
    use InteractsWithTenants, RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('catalog9', 'catalog9@test.local');
    }

    public function test_brand_crud(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $create = $this->postJson('/api/v1/brands', [
            'name' => 'Nike',
            'slug' => 'nike',
        ], $headers);

        $create->assertCreated()->assertJsonPath('data.name', 'Nike');
        $brandId = $create->json('data.id');

        $this->getJson("/api/v1/brands/{$brandId}", $headers)
            ->assertOk()
            ->assertJsonPath('data.slug', 'nike');

        $this->patchJson("/api/v1/brands/{$brandId}", ['name' => 'Nike Sport'], $headers)
            ->assertOk()
            ->assertJsonPath('data.name', 'Nike Sport');
    }

    public function test_unit_and_tax_crud(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $unit = $this->postJson('/api/v1/units', [
            'code' => 'kg',
            'name' => 'Kilogramme',
            'symbol' => 'kg',
            'is_fractional' => true,
        ], $headers)->assertCreated();

        $tax = $this->postJson('/api/v1/taxes', [
            'name' => 'TVA 18%',
            'code' => 'TVA18',
            'rate' => 18,
        ], $headers)->assertCreated();

        $this->assertDatabaseHas('units', ['code' => 'kg']);
        $this->assertDatabaseHas('taxes', ['code' => 'TVA18']);
    }

    public function test_category_show_and_tree(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $parent = $this->postJson("/api/v1/catalogs/{$catalog->id}/categories", [
            'name' => 'Vêtements',
            'slug' => 'vetements',
        ], $headers)->assertCreated()->json('data');

        $child = $this->postJson("/api/v1/catalogs/{$catalog->id}/categories", [
            'name' => 'T-shirts',
            'slug' => 't-shirts',
            'parent_id' => $parent['id'],
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/categories/{$child->json('data.id')}", $headers)
            ->assertOk()
            ->assertJsonPath('data.parent.id', $parent['id']);
    }

    public function test_simple_product_with_barcodes_and_prices(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $brand = Brand::create([
            'tenant_id' => $this->fixture['tenant']->id,
            'name' => 'Demo Brand',
            'slug' => 'demo-brand',
            'is_active' => true,
        ]);

        $response = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'PROD-SIMPLE-01',
            'name' => 'Produit simple',
            'product_type' => 'simple',
            'brand_id' => $brand->id,
            'base_price' => 5000,
            'cost_price' => 3000,
            'barcodes' => [
                ['barcode' => 'INT-SIMPLE-001', 'type' => 'internal', 'is_primary' => true],
            ],
            'prices' => [
                ['price_type' => 'base', 'amount' => 5000],
                ['price_type' => 'retail', 'amount' => 5500],
            ],
        ], $headers);

        $response->assertCreated()
            ->assertJsonPath('data.product_type', 'simple')
            ->assertJsonPath('data.brand_id', $brand->id);

        $productId = $response->json('data.id');

        $this->getJson("/api/v1/products/{$productId}/barcodes", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->getJson("/api/v1/products/{$productId}/prices", $headers)
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_variant_product_with_sizes_and_colors(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $response = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'TSHIRT-BASE',
            'name' => 'T-shirt coton',
            'product_type' => 'variant',
            'base_price' => 0,
            'variants' => [
                [
                    'sku' => 'TSHIRT-S-BLUE',
                    'size' => 'S',
                    'color' => 'Bleu',
                    'color_hex' => '#0000FF',
                    'base_price' => 4500,
                    'barcodes' => [['barcode' => 'VAR-S-BLUE', 'is_primary' => true]],
                ],
                [
                    'sku' => 'TSHIRT-M-RED',
                    'size' => 'M',
                    'color' => 'Rouge',
                    'color_hex' => '#FF0000',
                    'base_price' => 4500,
                ],
            ],
        ], $headers);

        $response->assertCreated()
            ->assertJsonPath('data.product_type', 'variant')
            ->assertJsonCount(2, 'data.variants');

        $productId = $response->json('data.id');

        $this->getJson("/api/v1/products/{$productId}/variants", $headers)
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_weighable_product(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $unit = Unit::create([
            'tenant_id' => $this->fixture['tenant']->id,
            'code' => 'kg',
            'name' => 'Kilogramme',
            'symbol' => 'kg',
            'is_fractional' => true,
            'is_active' => true,
        ]);

        $response = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'FRUIT-KG',
            'name' => 'Bananes',
            'product_type' => 'weighable',
            'unit_id' => $unit->id,
            'base_price' => 250,
        ], $headers);

        $response->assertCreated()
            ->assertJsonPath('data.product_type', 'weighable');
    }

    public function test_bundle_product(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $component = Product::create([
            'tenant_id' => $this->fixture['tenant']->id,
            'catalog_id' => $catalog->id,
            'sku' => 'COMP-01',
            'name' => 'Composant',
            'base_price' => 1000,
            'is_active' => true,
        ]);

        $response = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'BUNDLE-01',
            'name' => 'Pack déjeuner',
            'product_type' => 'bundle',
            'base_price' => 3500,
            'bundle_items' => [
                ['component_product_id' => $component->id, 'quantity' => 2],
            ],
        ], $headers);

        $response->assertCreated()
            ->assertJsonPath('data.product_type', 'bundle')
            ->assertJsonCount(1, 'data.bundle_items');
    }

    public function test_serialized_batch_expiration_flags(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $serialized = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'PHONE-01',
            'name' => 'Smartphone',
            'product_type' => 'serialized',
            'base_price' => 250000,
        ], $headers)->assertCreated();

        $this->assertTrue($serialized->json('data.is_serialized'));

        $batch = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'MED-01',
            'name' => 'Médicament',
            'product_type' => 'batch',
            'base_price' => 1500,
            'track_expiration' => true,
            'expiration_days' => 365,
        ], $headers)->assertCreated();

        $this->assertTrue($batch->json('data.track_batch'));
        $this->assertTrue($batch->json('data.track_expiration'));
    }

    public function test_service_product(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->postJson("/api/v1/catalogs/{$this->fixture['catalog']->id}/products", [
            'sku' => 'SVC-01',
            'name' => 'Installation',
            'product_type' => 'service',
            'base_price' => 10000,
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.product_type', 'service');
    }

    public function test_pos_sync_includes_variants_and_product_metadata(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];
        $store = $this->fixture['store'];

        $product = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'SYNC-VAR',
            'name' => 'Sync Test',
            'product_type' => 'variant',
            'base_price' => 0,
            'variants' => [
                ['sku' => 'SYNC-VAR-S', 'size' => 'S', 'base_price' => 3000],
            ],
        ], $headers)->assertCreated()->json('data');

        $this->fixture['product']->importToStore($store);
        Product::find($product['id'])->importToStore($store);

        $sync = app(PosCatalogSyncService::class)->productsForStore($store);
        $synced = collect($sync)->firstWhere('sku', 'SYNC-VAR');

        $this->assertNotNull($synced);
        $this->assertSame('variant', $synced['product_type']);
        $this->assertCount(1, $synced['variants']);
    }
}
