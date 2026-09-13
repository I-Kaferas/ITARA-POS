<?php

namespace App\Services\Catalog;

use App\Models\CatalogAttribute;

class CatalogAttributeService
{
    /**
     * Couleur and Taille so a product can become Rouge/S, Rouge/M, Bleu/S, Bleu/M.
     */
    public function ensureDefaults(string $tenantId): void
    {
        $defaults = [
            ['name' => 'Couleur', 'code' => 'color', 'values' => ['Rouge', 'Bleu'], 'sort_order' => 1],
            ['name' => 'Taille', 'code' => 'size', 'values' => ['S', 'M'], 'sort_order' => 2],
        ];

        foreach ($defaults as $attribute) {
            $existing = CatalogAttribute::withTrashed()
                ->where('tenant_id', $tenantId)
                ->where('code', $attribute['code'])
                ->first();

            if ($existing) {
                if ($existing->trashed()) {
                    $existing->restore();
                }
                continue;
            }

            CatalogAttribute::query()->create([
                'tenant_id' => $tenantId,
                'name' => $attribute['name'],
                'code' => $attribute['code'],
                'values' => $attribute['values'],
                'sort_order' => $attribute['sort_order'],
                'is_active' => true,
            ]);
        }
    }
}
