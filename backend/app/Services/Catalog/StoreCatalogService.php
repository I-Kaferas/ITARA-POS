<?php

namespace App\Services\Catalog;

use App\Models\Catalog;
use App\Models\Store;
use App\Models\Unit;

class StoreCatalogService
{
    /** @var list<array{code: string, name: string, symbol: string, is_fractional: bool}> */
    public const DEFAULT_UNITS = [
        ['code' => 'piece', 'name' => 'Pièce', 'symbol' => 'pc', 'is_fractional' => false],
        ['code' => 'kg', 'name' => 'Kilogramme', 'symbol' => 'kg', 'is_fractional' => true],
        ['code' => 'g', 'name' => 'Gramme', 'symbol' => 'g', 'is_fractional' => true],
        ['code' => 'L', 'name' => 'Litre', 'symbol' => 'L', 'is_fractional' => true],
        ['code' => 'h', 'name' => 'Heure', 'symbol' => 'h', 'is_fractional' => true],
    ];

    public function bootstrap(Store $store): Catalog
    {
        $store->loadMissing('branch');

        $catalog = $this->ensureCatalog($store);
        $this->ensureUnits($store);
        app(CatalogAttributeService::class)->ensureDefaults($store->tenant_id, $store->id);

        return $catalog;
    }

    public function ensureCatalog(Store $store): Catalog
    {
        $store->loadMissing('branch');

        $companyId = $store->branch?->company_id;
        if (! $companyId) {
            throw new \RuntimeException('Store has no company.');
        }

        $existing = Catalog::query()
            ->where('company_id', $companyId)
            ->orderByDesc('is_default')
            ->orderBy('created_at')
            ->first();

        if ($existing) {
            if ($existing->store_id !== null) {
                $existing->update(['store_id' => null]);
            }

            return $existing;
        }

        return Catalog::query()->create([
            'tenant_id' => $store->tenant_id,
            'company_id' => $companyId,
            'store_id' => null,
            'name' => 'Catalogue principal',
            'description' => 'Catalogue commun à tous les magasins',
            'is_default' => true,
            'is_active' => true,
        ]);
    }

    public function ensureUnits(Store $store): void
    {
        foreach (self::DEFAULT_UNITS as $unit) {
            Unit::query()->firstOrCreate(
                [
                    'tenant_id' => $store->tenant_id,
                    'store_id' => $store->id,
                    'code' => $unit['code'],
                ],
                [
                    'name' => $unit['name'],
                    'symbol' => $unit['symbol'],
                    'is_fractional' => $unit['is_fractional'],
                    'is_active' => true,
                ],
            );
        }
    }

    public function catalogForStore(Store $store): ?Catalog
    {
        $store->loadMissing('branch');
        $companyId = $store->branch?->company_id;
        if (! $companyId) {
            return null;
        }

        return Catalog::query()
            ->where('company_id', $companyId)
            ->orderByDesc('is_default')
            ->orderBy('created_at')
            ->first();
    }
}
