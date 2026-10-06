<?php

namespace App\Services\Organization;

use App\Models\Company;
use App\Models\Currency;
use App\Models\Role;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Payments\CompanyPaymentMethodService;
use App\Services\Platform\SaasCatalog;
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
     *     phone?: string|null,
     *     status?: string|null,
     *     plan?: string|null,
     *     admin_name?: string|null,
     *     admin_email?: string|null,
     *     admin_password?: string|null
     * }  $data
     * @return array{tenant: Tenant, company: ?Company, admin: ?User, idempotent: bool}
     */
    public function provision(array $data): array
    {
        return DB::transaction(function () use ($data) {
            $previous = $this->tenantContext->tenant();
            $name = trim($data['name']);
            $requestedSlug = Str::slug($data['slug'] ?? $name) ?: 'entreprise';
            $existing = Tenant::withTrashed()->where('slug', $requestedSlug)->first();
            if ($existing && ! $existing->trashed()) {
                return [
                    'tenant' => $existing,
                    'company' => Company::withoutGlobalScopes()->where('tenant_id', $existing->id)->first(),
                    'admin' => null,
                    'idempotent' => true,
                ];
            }

            $slug = $this->uniqueSlug($requestedSlug);
            $currency = strtoupper($data['currency_code'] ?? 'FBU');
            $locale = $data['locale'] ?? 'fr';
            $timezone = $data['timezone'] ?? 'Africa/Bujumbura';
            $status = $data['status'] ?? 'trial';
            $plan = array_key_exists($data['plan'] ?? '', SaasCatalog::PLANS) ? $data['plan'] : 'pos_stock';
            $settings = TenantBranding::demoSettings($name);
            $settings['saas'] = [
                'modules' => SaasCatalog::PLANS[$plan],
                'license' => [
                    'key' => 'ITARA-'.strtoupper(Str::random(4)).'-'.strtoupper(Str::random(4)),
                    'status' => 'active',
                    'seats' => 3,
                    'expires_on' => null,
                ],
                'subscription' => [
                    'plan' => $plan,
                    'status' => $status === 'trial' ? 'trial' : 'active',
                    'renews_on' => null,
                ],
                'support' => [],
            ];

            $tenant = Tenant::create([
                'name' => $name,
                'slug' => $slug,
                'status' => $status,
                'settings' => $settings,
            ]);

            $this->roles->provisionForTenant($tenant);
            $this->tenantContext->bind($tenant);
            $admin = null;

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

                if (! empty($data['admin_email'])) {
                    $admin = User::query()->create([
                        'tenant_id' => $tenant->id,
                        'name' => trim($data['admin_name'] ?? '') ?: $name,
                        'email' => $data['admin_email'],
                        'phone' => $data['phone'] ?? null,
                        'password' => $data['admin_password'],
                        'is_active' => true,
                    ]);
                    $adminRole = Role::query()
                        ->where('tenant_id', $tenant->id)
                        ->where('slug', 'administrator')
                        ->first();
                    if ($adminRole) {
                        $admin->roles()->attach($adminRole->id, [
                            'branch_id' => null,
                            'store_id' => null,
                        ]);
                    }
                }
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
                'admin' => $admin,
                'idempotent' => false,
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
