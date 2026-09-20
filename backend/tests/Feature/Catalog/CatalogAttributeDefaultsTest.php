<?php

namespace Tests\Feature\Catalog;

use App\Models\CatalogAttribute;
use App\Models\Store;
use App\Services\Catalog\CatalogAttributeService;
use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class CatalogAttributeDefaultsTest extends TestCase
{
    use InteractsWithTenants, RefreshDatabase;

    public function test_ensure_defaults_is_idempotent_for_a_store(): void
    {
        $fixture = $this->createTenantFixture('attr-defaults', 'attr-defaults@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $storeId = $fixture['store']->id;

        $this->getJson("/api/v1/catalog-attributes?ensure_defaults=1&store_id={$storeId}", $headers)->assertOk();
        $this->getJson("/api/v1/catalog-attributes?ensure_defaults=1&store_id={$storeId}", $headers)->assertOk();

        $this->assertSame(1, CatalogAttribute::query()->where('store_id', $storeId)->where('code', 'color')->count());
        $this->assertSame(1, CatalogAttribute::query()->where('store_id', $storeId)->where('code', 'size')->count());
    }

    public function test_each_store_can_have_the_same_attribute_code(): void
    {
        $fixture = $this->createTenantFixture('attr-stores', 'attr-stores@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);
        $secondStore = Store::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'branch_id' => $fixture['branch']->id,
            'name' => 'Store 2',
            'code' => 'ATTR02',
            'is_active' => true,
        ]);

        $service = app(CatalogAttributeService::class);
        $service->ensureDefaults($fixture['tenant']->id, $fixture['store']->id);
        $service->ensureDefaults($fixture['tenant']->id, $fixture['store']->id);
        $service->ensureDefaults($fixture['tenant']->id, $secondStore->id);

        $this->assertDatabaseHas('catalog_attributes', [
            'store_id' => $fixture['store']->id,
            'code' => 'color',
        ]);
        $this->assertDatabaseHas('catalog_attributes', [
            'store_id' => $secondStore->id,
            'code' => 'color',
        ]);
        $this->assertSame(2, CatalogAttribute::query()->where('code', 'color')->count());
    }
}
