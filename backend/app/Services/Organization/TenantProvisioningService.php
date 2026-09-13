<?php

namespace App\Services\Organization;

use App\Models\Company;
use App\Models\Currency;
use App\Models\Tenant;
use App\Services\Payments\CompanyPaymentMethodService;
use App\Services\Rbac\RoleProvisioningService;
use App\Support\TenantBranding;
use App\Tenancy\TenantContext;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TenantProvisioningService
{
    public function __construct(
        private readonly RoleProvisioningService $roles,
        private readonly CompanyTaxDefaults $taxes,
        private readonly CompanyPaymentMethodService $paymentMethods,
        private readonly TenantContext $tenantContext,
    ) {}

    /**
     * Create an isolated enterprise: tenant, company profile, currency, taxes and roles.
     *
     * @param  array{
     *     name: string,
     *     slug?: string|null,
     *     currency_code?: string|null,
     *     locale?: string|null,
     *     timezone?: string|null,
     *     email?: string|null,
     *     phone?: string|null
     * }  $data
     * @return array{tenant: Tenant, company: Company}
     */
    public function provision(array $data): array
    {
        return DB::transaction(function () use ($data) {
            $previous = $this->tenantContext->tenant();
            $name = trim($data['name']);
            $slug = $this->uniqueSlug($data['slug'] ?? Str::slug($name));
            $currency = strtoupper($data['currency_code'] ?? 'FBU');
            $locale = $data['locale'] ?? 'fr';
            $timezone = $data['timezone'] ?? 'Africa/Bujumbura';

            $tenant = Tenant::create([
                'name' => $name,
                'slug' => $slug,
                'status' => 'active',
                'settings' => TenantBranding::demoSettings($name),
            ]);

            $this->roles->provisionForTenant($tenant);
            $this->tenantContext->bind($tenant);

            try {
                $company = Company::create([
                    'tenant_id' => $tenant->id,
                    'name' => $name,
                    'trade_name' => $name,
                    'email' => $data['email'] ?? null,
                    'phone' => $data['phone'] ?? null,
                    'currency_code' => $currency,
                    'locale' => $locale,
                    'timezone' => $timezone,
                    'settings' => [
                        'locale' => $locale,
                        'timezone' => $timezone,
                    ],
                    'is_active' => true,
                ]);

                Currency::query()->firstOrCreate(
                    ['tenant_id' => $tenant->id, 'code' => $currency],
                    [
                        'tenant_id' => $tenant->id,
                        'name' => $currency,
                        'symbol' => $currency,
                        'decimal_places' => $currency === 'FBU' ? 0 : 2,
                        'exchange_rate' => 1,
                        'is_default' => true,
                        'is_active' => true,
                    ],
                );

                $this->taxes->ensure($tenant->id);
                $this->paymentMethods->ensureDefaults($company);
                app(BranchEstablishmentService::class)->ensure($company);
            } finally {
                if ($previous !== null) {
                    $this->tenantContext->bind($previous);
                } else {
                    $this->tenantContext->clear();
                }
            }

            return [
                'tenant' => $tenant->fresh(),
                'company' => $company->fresh(),
            ];
        });
    }

    private function uniqueSlug(string $slug): string
    {
        $base = Str::slug($slug) ?: 'entreprise';
        $candidate = $base;
        $suffix = 2;

        while (Tenant::withTrashed()->where('slug', $candidate)->exists()) {
            $candidate = $base.'-'.$suffix;
            $suffix++;
        }

        return $candidate;
    }
}
