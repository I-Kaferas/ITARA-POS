<?php

namespace App\Services\Catalog;

use App\Models\CatalogAttribute;
use Illuminate\Database\UniqueConstraintViolationException;

class CatalogAttributeService
{
    /**
     * Couleur and Taille so a product can become Rouge/S, Rouge/M, Bleu/S, Bleu/M.
     */
    public function ensureDefaults(string $tenantId, ?string $storeId = null): void
    {
        if ($storeId === null || $storeId === '') {
            return;
        }

        $defaults = [
            ['name' => 'Couleur', 'code' => 'color', 'values' => ['Rouge', 'Bleu'], 'sort_order' => 1],
            ['name' => 'Taille', 'code' => 'size', 'values' => ['S', 'M'], 'sort_order' => 2],
        ];

        foreach ($defaults as $attribute) {
            $this->ensureAttribute($tenantId, $storeId, $attribute);
        }
    }

    /**
     * @param  array{name: string, code: string, values: list<string>, sort_order: int}  $attribute
     */
    private function ensureAttribute(string $tenantId, string $storeId, array $attribute): void
    {
        $existing = CatalogAttribute::withTrashed()
            ->where('tenant_id', $tenantId)
            ->where('code', $attribute['code'])
            ->where(function ($query) use ($storeId) {
                $query->where('store_id', $storeId)->orWhereNull('store_id');
            })
            ->orderByRaw('case when store_id is null then 1 else 0 end')
            ->first();

        if ($existing) {
            if ($existing->trashed()) {
                $existing->restore();
            }

            if ($existing->store_id === null) {
                $existing->update(['store_id' => $storeId]);
            }

            return;
        }

        try {
            CatalogAttribute::query()->create([
                'tenant_id' => $tenantId,
                'store_id' => $storeId,
                'name' => $attribute['name'],
                'code' => $attribute['code'],
                'values' => $attribute['values'],
                'sort_order' => $attribute['sort_order'],
                'is_active' => true,
            ]);
        } catch (UniqueConstraintViolationException) {
            $retry = CatalogAttribute::withTrashed()
                ->where('tenant_id', $tenantId)
                ->where('code', $attribute['code'])
                ->where(function ($query) use ($storeId) {
                    $query->where('store_id', $storeId)->orWhereNull('store_id');
                })
                ->first();

            if ($retry) {
                if ($retry->trashed()) {
                    $retry->restore();
                }
                if ($retry->store_id === null) {
                    $retry->update(['store_id' => $storeId]);
                }
            }
        }
    }
}
