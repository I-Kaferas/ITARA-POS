<?php

namespace Database\Seeders;

use App\Models\Store;
use App\Models\Tax;
use App\Models\Tenant;
use App\Services\Catalog\StoreCatalogService;
use Illuminate\Database\Seeder;

class CatalogMasterDataSeeder extends Seeder
{
    public function run(): void
    {
        $tenant = Tenant::query()->where('slug', 'demo')->first();

        if (! $tenant) {
            return;
        }

        Tax::query()->firstOrCreate(
            ['tenant_id' => $tenant->id, 'code' => 'TVA18'],
            [
                'tenant_id' => $tenant->id,
                'name' => 'TVA 18%',
                'rate' => 18,
                'is_inclusive' => false,
                'is_active' => true,
            ],
        );

        $bootstrap = app(StoreCatalogService::class);
        Store::query()
            ->where('tenant_id', $tenant->id)
            ->get()
            ->each(fn (Store $store) => $bootstrap->bootstrap($store));
    }
}
