<?php

namespace App\Services\Tax;

use App\Enums\TaxComputationType;
use App\Enums\TaxKind;
use App\Models\Tax;
use App\Models\TaxClass;
use App\Models\TaxGroup;
use App\Models\TaxRule;
use App\Models\Tenant;
use Illuminate\Support\Str;

/**
 * Copies a locale tax package into a tenant's own tables.
 * Profiles are data (config/tax_profiles.php) — never hard-coded in TaxEngine.
 */
class TaxProfileInstaller
{
    /**
     * Install (idempotent) the best matching profile for a tenant.
     *
     * @return array{profile: string, created: list<string>}
     */
    public function ensureForTenant(Tenant|string $tenant): array
    {
        $tenantId = $tenant instanceof Tenant ? $tenant->id : $tenant;
        $model = $tenant instanceof Tenant ? $tenant : Tenant::query()->find($tenantId);
        $key = $this->resolveProfileKey($model);

        return $this->install($tenantId, $key);
    }

    /**
     * @return array{profile: string, created: list<string>}
     */
    public function install(string $tenantId, string $profileKey): array
    {
        $profile = config("tax_profiles.profiles.{$profileKey}");
        if (! is_array($profile)) {
            $fallback = (string) config('tax_profiles.default', 'BI');
            $profile = config("tax_profiles.profiles.{$fallback}", []);
            $profileKey = $fallback;
        }

        $created = [];
        $taxIds = [];
        $classIds = [];
        $groupIds = [];

        foreach ($profile['taxes'] ?? [] as $row) {
            $tax = Tax::query()->firstOrCreate(
                ['tenant_id' => $tenantId, 'code' => $row['code']],
                [
                    'tenant_id' => $tenantId,
                    'name' => $row['name'],
                    'kind' => TaxKind::tryFrom($row['kind'] ?? '')?->value ?? TaxKind::Vat->value,
                    'type' => TaxComputationType::tryFrom($row['type'] ?? '')?->value ?? TaxComputationType::Percentage->value,
                    'rate' => $row['rate'] ?? 0,
                    'priority' => $row['priority'] ?? 1,
                    'country' => $row['country'] ?? ($profile['country'] ?? null),
                    'region' => $row['region'] ?? null,
                    'is_inclusive' => (bool) ($row['is_inclusive'] ?? false),
                    'is_compound' => (bool) ($row['is_compound'] ?? false),
                    'is_active' => true,
                    'description' => $row['description'] ?? null,
                ],
            );
            $taxIds[$row['code']] = $tax->id;
            if ($tax->wasRecentlyCreated) {
                $created[] = 'tax:'.$row['code'];
            }
        }

        foreach ($profile['classes'] ?? [] as $row) {
            $class = TaxClass::query()->firstOrCreate(
                ['tenant_id' => $tenantId, 'code' => $row['code']],
                [
                    'tenant_id' => $tenantId,
                    'name' => $row['name'],
                    'description' => $row['description'] ?? null,
                    'is_active' => true,
                ],
            );
            $classIds[$row['code']] = $class->id;
            if ($class->wasRecentlyCreated) {
                $created[] = 'class:'.$row['code'];
            }
        }

        foreach ($profile['groups'] ?? [] as $row) {
            $group = TaxGroup::query()->firstOrCreate(
                ['tenant_id' => $tenantId, 'code' => $row['code']],
                [
                    'tenant_id' => $tenantId,
                    'name' => $row['name'],
                    'description' => $row['description'] ?? null,
                    'is_active' => true,
                ],
            );
            $groupIds[$row['code']] = $group->id;
            if ($group->wasRecentlyCreated) {
                $created[] = 'group:'.$row['code'];
            }

            $sync = [];
            foreach (array_values($row['tax_codes'] ?? []) as $index => $code) {
                if (! isset($taxIds[$code])) {
                    continue;
                }
                $sync[$taxIds[$code]] = ['id' => (string) Str::uuid(), 'sort_order' => $index];
            }
            if ($sync !== []) {
                $group->taxes()->syncWithoutDetaching($sync);
            }
        }

        foreach ($profile['rules'] ?? [] as $row) {
            $classId = isset($row['class_code']) ? ($classIds[$row['class_code']] ?? null) : null;
            $taxId = isset($row['tax_code']) ? ($taxIds[$row['tax_code']] ?? null) : null;
            $groupId = isset($row['group_code']) ? ($groupIds[$row['group_code']] ?? null) : null;
            if (! $classId || (! $taxId && ! $groupId)) {
                continue;
            }

            $rule = TaxRule::query()->firstOrCreate(
                [
                    'tenant_id' => $tenantId,
                    'name' => $row['name'],
                    'tax_class_id' => $classId,
                ],
                [
                    'tenant_id' => $tenantId,
                    'name' => $row['name'],
                    'tax_class_id' => $classId,
                    'tax_id' => $taxId,
                    'tax_group_id' => $groupId,
                    'country' => $row['country'] ?? ($profile['country'] ?? null),
                    'region' => $row['region'] ?? null,
                    'priority' => $row['priority'] ?? 1,
                    'is_active' => true,
                    'description' => $row['description'] ?? null,
                ],
            );
            if ($rule->wasRecentlyCreated) {
                $created[] = 'rule:'.$row['name'];
            }
        }

        return ['profile' => $profileKey, 'created' => $created];
    }

    /** @return list<array{key: string, name: string, country: ?string, description: ?string}> */
    public function availableProfiles(): array
    {
        $out = [];
        foreach (config('tax_profiles.profiles', []) as $key => $profile) {
            $out[] = [
                'key' => $key,
                'name' => $profile['name'] ?? $key,
                'country' => $profile['country'] ?? null,
                'description' => $profile['description'] ?? null,
            ];
        }

        return $out;
    }

    private function resolveProfileKey(?Tenant $tenant): string
    {
        $default = (string) config('tax_profiles.default', 'BI');
        if ($tenant === null) {
            return $default;
        }

        $regime = $tenant->tax_regime ? strtoupper((string) $tenant->tax_regime) : null;
        if ($regime && config("tax_profiles.profiles.{$regime}")) {
            return $regime;
        }

        $country = $tenant->country_code ? strtoupper((string) $tenant->country_code) : null;
        if ($country && config("tax_profiles.profiles.{$country}")) {
            return $country;
        }

        return $default;
    }
}
