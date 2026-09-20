<?php

namespace Tests\Feature\Catalog;

use App\Models\Brand;
use App\Models\CatalogAttribute;
use App\Models\Category;
use App\Models\Store;
use App\Models\Unit;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class CatalogMultiStoreCreateTest extends TestCase
{
    use InteractsWithTenants, RefreshDatabase;

    private array $fixture;

    private Store $secondStore;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('multistore', 'multistore@test.local');
        $this->secondStore = Store::create([
            'tenant_id' => $this->fixture['tenant']->id,
            'branch_id' => $this->fixture['branch']->id,
            'name' => 'Store 2',
            'code' => 'MULTISTORE02',
            'is_active' => true,
        ]);
    }

    public function test_brand_is_created_in_each_selected_store(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $storeA = $this->fixture['store']->id;
        $storeB = $this->secondStore->id;

        $this->postJson('/api/v1/brands', [
            'name' => 'Nike',
            'slug' => 'nike',
            'store_ids' => [$storeA, $storeB],
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('created_count', 2);

        $this->assertSame(2, Brand::query()->where('slug', 'nike')->count());
        $this->assertTrue(Brand::query()->where('slug', 'nike')->where('store_id', $storeA)->exists());
        $this->assertTrue(Brand::query()->where('slug', 'nike')->where('store_id', $storeB)->exists());
    }

    public function test_unit_is_created_in_each_selected_store(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->postJson('/api/v1/units', [
            'code' => 'box',
            'name' => 'Boîte',
            'symbol' => 'box',
            'store_ids' => [$this->fixture['store']->id, $this->secondStore->id],
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('created_count', 2);

        $this->assertSame(2, Unit::query()->where('code', 'box')->count());
    }

    public function test_attribute_is_created_in_each_selected_store(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->postJson('/api/v1/catalog-attributes', [
            'name' => 'Couleur',
            'code' => 'color',
            'values' => ['Rouge', 'Bleu'],
            'store_ids' => [$this->fixture['store']->id, $this->secondStore->id],
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('created_count', 2);

        $this->assertSame(2, CatalogAttribute::query()->where('code', 'color')->count());
    }

    public function test_category_is_created_in_each_selected_store(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $this->postJson("/api/v1/catalogs/{$catalog->id}/categories", [
            'name' => 'Boissons',
            'slug' => 'boissons',
            'store_ids' => [$this->fixture['store']->id, $this->secondStore->id],
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('created_count', 2);

        $this->assertSame(2, Category::query()->where('slug', 'boissons')->count());
    }

    public function test_create_requires_at_least_one_store(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->postJson('/api/v1/brands', [
            'name' => 'Adidas',
            'slug' => 'adidas',
        ], $headers)->assertStatus(422);
    }

    public function test_brand_update_applies_to_selected_stores(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $storeA = $this->fixture['store']->id;
        $storeB = $this->secondStore->id;

        $brandId = $this->postJson('/api/v1/brands', [
            'name' => 'Puma',
            'slug' => 'puma',
            'store_id' => $storeA,
        ], $headers)->assertCreated()->json('data.id');

        $this->patchJson("/api/v1/brands/{$brandId}", [
            'name' => 'Puma Sport',
            'slug' => 'puma',
            'store_ids' => [$storeA, $storeB],
        ], $headers)
            ->assertOk()
            ->assertJsonPath('updated_count', 2)
            ->assertJsonPath('data.name', 'Puma Sport');

        $this->assertSame(2, Brand::query()->where('slug', 'puma')->where('name', 'Puma Sport')->count());
    }

    public function test_unit_update_applies_to_selected_stores(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $storeA = $this->fixture['store']->id;
        $storeB = $this->secondStore->id;

        $unitId = $this->postJson('/api/v1/units', [
            'code' => 'pack',
            'name' => 'Pack',
            'store_id' => $storeA,
        ], $headers)->assertCreated()->json('data.id');

        $this->patchJson("/api/v1/units/{$unitId}", [
            'name' => 'Paquet',
            'code' => 'pack',
            'store_ids' => [$storeA, $storeB],
        ], $headers)->assertOk()->assertJsonPath('updated_count', 2);

        $this->assertSame(2, Unit::query()->where('code', 'pack')->where('name', 'Paquet')->count());
    }

    public function test_attribute_update_applies_to_selected_stores(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $storeA = $this->fixture['store']->id;
        $storeB = $this->secondStore->id;

        $attributeId = $this->postJson('/api/v1/catalog-attributes', [
            'name' => 'Taille',
            'code' => 'size',
            'values' => ['S', 'M'],
            'store_id' => $storeA,
        ], $headers)->assertCreated()->json('data.id');

        $this->patchJson("/api/v1/catalog-attributes/{$attributeId}", [
            'name' => 'Taille',
            'code' => 'size',
            'values' => ['S', 'M', 'L'],
            'store_ids' => [$storeA, $storeB],
        ], $headers)->assertOk()->assertJsonPath('updated_count', 2);

        $this->assertSame(2, CatalogAttribute::query()->where('code', 'size')->count());
        $copied = CatalogAttribute::query()->where('store_id', $storeB)->where('code', 'size')->first();
        $this->assertNotNull($copied);
        $this->assertContains('L', $copied->values);
    }

    public function test_category_update_applies_to_selected_stores(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];
        $storeA = $this->fixture['store']->id;
        $storeB = $this->secondStore->id;

        $categoryId = $this->postJson("/api/v1/catalogs/{$catalog->id}/categories", [
            'name' => 'Snacks',
            'slug' => 'snacks',
            'store_id' => $storeA,
        ], $headers)->assertCreated()->json('data.id');

        $this->patchJson("/api/v1/categories/{$categoryId}", [
            'name' => 'Encas',
            'slug' => 'snacks',
            'store_ids' => [$storeA, $storeB],
        ], $headers)->assertOk()->assertJsonPath('updated_count', 2);

        $this->assertSame(2, Category::query()->where('slug', 'snacks')->where('name', 'Encas')->count());
    }
}
