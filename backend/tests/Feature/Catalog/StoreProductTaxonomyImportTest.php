<?php

namespace Tests\Feature\Catalog;

use App\Models\Brand;
use App\Models\CatalogAttribute;
use App\Models\Category;
use App\Models\Product;
use App\Models\Unit;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class StoreProductTaxonomyImportTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_import_assigns_store_category_brand_and_unit(): void
    {
        $fixture = $this->createTenantFixture('store-tax', 'store-tax@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $store = $fixture['store'];
        $catalog = $fixture['catalog'];
        $product = $fixture['product'];

        $category = Category::create([
            'tenant_id' => $fixture['tenant']->id,
            'catalog_id' => $catalog->id,
            'store_id' => $store->id,
            'name' => 'Boissons',
            'slug' => 'boissons',
            'sort_order' => 1,
            'is_active' => true,
        ]);

        $brand = Brand::create([
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $store->id,
            'name' => 'Itara',
            'slug' => 'itara',
            'is_active' => true,
        ]);

        $unit = Unit::query()->where('store_id', $store->id)->first()
            ?? Unit::create([
                'tenant_id' => $fixture['tenant']->id,
                'store_id' => $store->id,
                'code' => 'pcs',
                'name' => 'Pièce',
                'symbol' => 'pcs',
                'is_active' => true,
            ]);

        $this->postJson("/api/v1/stores/{$store->id}/products/import", [
            'product_ids' => [$product->id],
            'category_id' => $category->id,
            'brand_id' => $brand->id,
            'unit_id' => $unit->id,
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.0.category_id', $category->id)
            ->assertJsonPath('data.0.brand_id', $brand->id)
            ->assertJsonPath('data.0.unit_id', $unit->id);

        $this->assertDatabaseHas('store_products', [
            'store_id' => $store->id,
            'product_id' => $product->id,
            'category_id' => $category->id,
            'brand_id' => $brand->id,
            'unit_id' => $unit->id,
        ]);

        $this->patchJson("/api/v1/stores/{$store->id}/products/{$product->id}", [
            'category_id' => null,
            'brand_id' => $brand->id,
            'unit_id' => $unit->id,
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.category_id', null)
            ->assertJsonPath('data.brand_id', $brand->id);
    }

    public function test_import_rejects_taxonomy_from_another_store(): void
    {
        $fixture = $this->createTenantFixture('store-tax-x', 'store-tax-x@test.local');
        $other = $this->createTenantFixture('store-tax-y', 'store-tax-y@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $foreignBrand = Brand::create([
            'tenant_id' => $other['tenant']->id,
            'store_id' => $other['store']->id,
            'name' => 'Foreign',
            'slug' => 'foreign',
            'is_active' => true,
        ]);

        $this->postJson("/api/v1/stores/{$fixture['store']->id}/products/import", [
            'product_ids' => [$fixture['product']->id],
            'brand_id' => $foreignBrand->id,
        ], $headers)->assertStatus(422);
    }

    public function test_import_and_bulk_classify_assign_attributes(): void
    {
        $fixture = $this->createTenantFixture('store-attr', 'store-attr@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $store = $fixture['store'];
        $product = $fixture['product'];
        $second = Product::create([
            'tenant_id' => $fixture['tenant']->id,
            'catalog_id' => $fixture['catalog']->id,
            'sku' => 'STORE-ATTR-2',
            'name' => 'Second product',
            'base_price' => 800,
            'is_active' => true,
        ]);

        $attribute = CatalogAttribute::create([
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $store->id,
            'name' => 'Couleur',
            'code' => 'couleur',
            'values' => ['Rouge', 'Bleu'],
            'is_active' => true,
        ]);

        $this->postJson("/api/v1/stores/{$store->id}/products/import", [
            'product_ids' => [$product->id, $second->id],
            'attributes' => [
                ['attribute_id' => $attribute->id, 'value' => 'Rouge'],
            ],
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.0.attributes.0.value', 'Rouge')
            ->assertJsonPath('data.1.attributes.0.value', 'Rouge');

        $this->postJson("/api/v1/stores/{$store->id}/products/classify", [
            'product_ids' => [$product->id, $second->id],
            'attributes' => [
                ['attribute_id' => $attribute->id, 'value' => 'Bleu'],
            ],
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.0.attributes.0.value', 'Bleu')
            ->assertJsonPath('data.1.attributes.0.value', 'Bleu');
    }
}
