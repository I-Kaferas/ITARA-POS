<?php

namespace Tests\Feature\Catalog;

use App\Models\Branch;
use App\Models\Catalog;
use App\Models\Company;
use App\Models\Product;
use App\Models\Store;
use App\Models\Tenant;
use App\Services\Catalog\PosCatalogSyncService;
use App\Services\Catalog\ProductImageService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProductImageGalleryTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'media.disk' => 's3',
            'media.cdn_url' => 'https://cdn.pos.local/pos-uploads',
        ]);

        Storage::fake('s3');
    }

    public function test_product_can_have_image_gallery_with_cdn_urls(): void
    {
        $product = $this->createProduct();
        $service = app(ProductImageService::class);

        $imageA = $service->upload($product, UploadedFile::fake()->image('photo-a.jpg'), isPrimary: true);
        $imageB = $service->upload($product, UploadedFile::fake()->image('photo-b.png'));

        $this->assertDatabaseCount('product_images', 2);
        $this->assertTrue($imageA->is_primary);
        $this->assertFalse($imageB->is_primary);
        $this->assertStringStartsWith('https://cdn.pos.local/pos-uploads/', $imageA->cdn_url);
        $this->assertStringContainsString($product->tenant_id, $imageA->storage_path);
        Storage::disk('s3')->assertExists($imageA->storage_path);
    }

    public function test_gallery_can_be_reordered_and_primary_changed(): void
    {
        $product = $this->createProduct();
        $service = app(ProductImageService::class);

        $imageA = $service->upload($product, UploadedFile::fake()->image('a.jpg'), isPrimary: true);
        $imageB = $service->upload($product, UploadedFile::fake()->image('b.jpg'));

        $service->setPrimary($imageB);
        $service->reorder($product, [$imageB->id, $imageA->id]);

        $this->assertTrue($imageB->fresh()->is_primary);
        $this->assertFalse($imageA->fresh()->is_primary);
        $this->assertSame(0, $imageB->fresh()->sort_order);
        $this->assertSame(1, $imageA->fresh()->sort_order);
    }

    public function test_pos_sync_includes_cdn_image_gallery_for_imported_products(): void
    {
        $context = $this->createStoreContext();
        $product = $context['product'];
        $store = $context['store'];

        $service = app(ProductImageService::class);
        $service->upload($product, UploadedFile::fake()->image('main.jpg'), isPrimary: true);
        $service->upload($product, UploadedFile::fake()->image('detail.jpg'));

        $product->importToStore($store);

        $payload = app(PosCatalogSyncService::class)->productsForStore($store);

        $this->assertCount(1, $payload);
        $this->assertSame('SKU-IMG', $payload[0]['sku']);
        $this->assertNotNull($payload[0]['primary_image_cdn_url']);
        $this->assertCount(2, $payload[0]['images']);
        $this->assertStringStartsWith('https://cdn.pos.local/pos-uploads/', $payload[0]['images'][0]['cdn_url']);
        $this->assertArrayHasKey('cdn_url', $payload[0]['images'][0]);
        $this->assertArrayNotHasKey('storage_path', $payload[0]['images'][0]);
    }

    public function test_deleting_primary_image_promotes_next_gallery_photo(): void
    {
        $product = $this->createProduct();
        $service = app(ProductImageService::class);

        $primary = $service->upload($product, UploadedFile::fake()->image('primary.jpg'), isPrimary: true);
        $secondary = $service->upload($product, UploadedFile::fake()->image('secondary.jpg'));

        $service->delete($primary);

        $this->assertTrue($secondary->fresh()->is_primary);
        $this->assertSoftDeleted($primary);
    }

    private function createProduct(): Product
    {
        $tenant = Tenant::create(['name' => 'T', 'slug' => 't', 'status' => 'active']);
        $company = Company::create(['tenant_id' => $tenant->id, 'name' => 'C', 'is_active' => true]);
        $catalog = Catalog::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'Catalogue',
            'is_default' => true,
        ]);

        return Product::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'sku' => 'SKU-GAL',
            'name' => 'Produit avec photos',
            'base_price' => 1000,
        ]);
    }

    /**
     * @return array{store: Store, product: Product}
     */
    private function createStoreContext(): array
    {
        $tenant = Tenant::create(['name' => 'T', 'slug' => 't2', 'status' => 'active']);
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
        $product = Product::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'sku' => 'SKU-IMG',
            'name' => 'Produit photo',
            'base_price' => 500,
        ]);

        return compact('store', 'product');
    }
}
