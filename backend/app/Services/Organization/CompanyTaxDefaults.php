<?php

namespace App\Services\Organization;

use App\Models\Tax;

class CompanyTaxDefaults
{
    /**
     * Each enterprise keeps its own tax rates. Existing rates are left untouched.
     */
    public function ensure(string $tenantId): void
    {
        $defaults = [
            ['code' => 'TVA18', 'name' => 'TVA 18%', 'rate' => 18, 'is_inclusive' => false],
            ['code' => 'EXO', 'name' => 'Exonéré', 'rate' => 0, 'is_inclusive' => false],
        ];

        foreach ($defaults as $tax) {
            Tax::query()->firstOrCreate(
                ['tenant_id' => $tenantId, 'code' => $tax['code']],
                [
                    'tenant_id' => $tenantId,
                    'name' => $tax['name'],
                    'rate' => $tax['rate'],
                    'is_inclusive' => $tax['is_inclusive'],
                    'is_active' => true,
                ],
            );
        }
    }
}
