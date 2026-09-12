<?php

namespace Tests\Feature\Catalog;

use App\Models\Branch;
use App\Models\Catalog;
use App\Models\Company;
use App\Models\Product;
use App\Models\Store;
use App\Models\Tenant;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CatalogStoreImportTest extends TestCase
{
    use RefreshDatabase;

    public function test_catalog_product_can_be_imported_into_specific_stores(): void
    {
        $tenant = Tenant::create([
            'name' => 'Demo Tenant',
            'slug' => 'demo',
            'status' => 'active',
        ]);

        $company = Company::create([
            'tenant_id' => $tenant->id,
            'name' => 'Ma Boutique',
            'currency_code' => 'USD',
            'is_active' => true,
        ]);

        $catalog = Catalog::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'Catalogue principal',
            'is_default' => true,
            'is_active' => true,
        ]);

        $branch = Branch::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'Siège',
            'code' => 'HQ',
            'is_active' => true,
        ]);

        $storeX = Store::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Store X',
            'code' => 'STX',
            'is_active' => true,
        ]);

        $storeY = Store::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Store Y',
            'code' => 'STY',
            'is_active' => true,
        ]);

        $product = Product::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'sku' => 'SKU-001',
            'name' => 'Produit A',
            'base_price' => 1500,
            'cost_price' => 800,
            'is_active' => true,
        ]);

        $catalog->importToStore($storeX, [$product]);
        $product->importToStore($storeY, priceOverride: 2000);

        $this->assertTrue($product->isImportedInStore($storeX));
        $this->assertTrue($product->isImportedInStore($storeY));
        $this->assertFalse($product->isImportedInStore(Store::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Store Z',
            'code' => 'STZ',
            'is_active' => true,
        ])));

        $this->assertSame(1500, $product->priceForStore($storeX));
        $this->assertSame(2000, $product->priceForStore($storeY));

        $this->assertDatabaseCount('store_products', 2);
        $this->assertDatabaseHas('store_products', [
            'store_id' => $storeX->id,
            'product_id' => $product->id,
            'is_available' => true,
        ]);
        $this->assertDatabaseHas('store_products', [
            'store_id' => $storeY->id,
            'product_id' => $product->id,
            'price_override' => 2000,
        ]);
    }

    public function test_store_only_sees_imported_products(): void
    {
        $tenant = Tenant::create(['name' => 'T', 'slug' => 't', 'status' => 'active']);
        $company = Company::create(['tenant_id' => $tenant->id, 'name' => 'C', 'is_active' => true]);
        $catalog = Catalog::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'Catalogue',
            'is_default' => true,
        ]);
        $branch = Branch::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'B',
            'code' => 'B1',
        ]);
        $store = Store::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Store',
            'code' => 'S1',
        ]);

        $imported = Product::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'sku' => 'A',
            'name' => 'Imported',
            'base_price' => 100,
        ]);
        Product::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'sku' => 'B',
            'name' => 'Not imported',
            'base_price' => 200,
        ]);

        $imported->importToStore($store);

        $this->assertCount(1, $store->fresh()->availableProducts);
        $this->assertSame('Imported', $store->availableProducts->first()->name);
    }
}
