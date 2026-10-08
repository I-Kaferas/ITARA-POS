<?php

namespace App\Services\Organization;

use App\Models\Tenant;
use App\Services\Tax\TaxProfileInstaller;

class CompanyTaxDefaults
{
    public function __construct(private readonly TaxProfileInstaller $profiles) {}

    /**
     * Each enterprise keeps its own tax rates. Existing rates are left untouched.
     * Locale packs (e.g. Burundi) are applied as tenant-owned rows from config profiles.
     */
    public function ensure(string $tenantId): void
    {
        $tenant = Tenant::query()->find($tenantId);
        $this->profiles->ensureForTenant($tenant ?? $tenantId);
    }
}
