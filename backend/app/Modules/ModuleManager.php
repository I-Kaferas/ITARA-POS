<?php

namespace App\Modules;

use App\Models\SaasPlan;
use App\Models\SaasSubscription;
use App\Models\Tenant;
use App\Services\Platform\SaasPlanCatalog;
use Illuminate\Validation\ValidationException;

class ModuleManager
{
    /**
     * Enabled module codes for a tenant.
     * An empty saved list means every module is on, matching the previous catalog.
     *
     * @return list<string>
     */
    public function enabledCodes(?Tenant $tenant): array
    {
        if ($tenant === null) {
            return ModuleRegistry::CODES;
        }

        $saved = $tenant->settings['saas']['modules'] ?? null;
        if (! is_array($saved) || $saved === []) {
            return ModuleRegistry::DEFAULTS;
        }

        $normalized = ModuleRegistry::normalize($saved);

        return $normalized === [] ? ModuleRegistry::CODES : $normalized;
    }

    public function isEnabled(string $code, ?Tenant $tenant): bool
    {
        return in_array(ModuleRegistry::canonical($code), $this->enabledCodes($tenant), true);
    }

    /**
     * @return list<string>
     */
    public function allowsAny(array $codes, ?Tenant $tenant): bool
    {
        foreach ($codes as $code) {
            if ($this->isEnabled($code, $tenant)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Modules included in the tenant's active SaaS plan.
     * Empty when there is no subscription row (legacy / unconstrained tenants).
     *
     * @return list<string>
     */
    public function planCodes(?Tenant $tenant): array
    {
        if ($tenant === null) {
            return ModuleRegistry::CODES;
        }

        $subscription = SaasSubscription::query()->where('tenant_id', $tenant->id)->first();
        if ($subscription === null) {
            return [];
        }

        $plan = SaasPlan::query()->where('code', $subscription->plan_code)->first();
        if ($plan !== null) {
            return $plan->modules();
        }

        $definition = SaasPlanCatalog::definitions()[$subscription->plan_code] ?? null;
        if (! is_array($definition)) {
            return [];
        }

        return ModuleRegistry::normalize($definition['limits']['modules'] ?? []);
    }

    /**
     * Catalog rows for modules the tenant may see.
     * Modules outside the plan (and not already enabled) are omitted so the UI
     * never advertises features that return errors.module_disabled.
     *
     * @return list<array{code: string, icon: string, enabled: bool}>
     */
    public function catalog(?Tenant $tenant): array
    {
        $enabled = $this->enabledCodes($tenant);
        $plan = $this->planCodes($tenant);
        $visible = $plan === []
            ? $enabled
            : ModuleRegistry::normalize([...$plan, ...$enabled]);

        return array_map(function (string $code) use ($enabled) {
            $definition = ModuleRegistry::definition($code);

            return [
                'code' => $code,
                'icon' => $definition['icon'],
                'enabled' => in_array($code, $enabled, true),
            ];
        }, $visible);
    }

    /**
     * Full manifest of enabled modules only.
     *
     * @return list<array<string, mixed>>
     */
    public function manifest(?Tenant $tenant): array
    {
        $rows = [];
        foreach ($this->enabledCodes($tenant) as $code) {
            $definition = ModuleRegistry::definition($code);
            if ($definition === null) {
                continue;
            }
            $rows[] = [
                'code' => $code,
                'icon' => $definition['icon'],
                'permissions' => ModuleRegistry::permissionSlugs($code),
                'settings' => $this->settingFields($tenant, $code),
                'navigation' => $definition['navigation'],
                'widgets' => $definition['widgets'],
                'routes' => [
                    'api' => $definition['api'],
                    'web' => $definition['web'],
                ],
            ];
        }

        return $rows;
    }

    /**
     * @return array<string, mixed>
     */
    public function settings(?Tenant $tenant, string $code): array
    {
        $definition = $this->requireEnabled($tenant, $code);
        $stored = [];
        if ($tenant !== null) {
            $bag = $tenant->settings['module_settings'][$definition['code']] ?? [];
            $stored = is_array($bag) ? $bag : [];
        }

        $values = [];
        foreach ($definition['settings'] as $field) {
            $key = $field['key'];
            $values[$key] = array_key_exists($key, $stored) ? $stored[$key] : $field['default'];
        }

        return $values;
    }

    /**
     * @param  array<string, mixed>  $input
     * @return array<string, mixed>
     */
    public function updateSettings(Tenant $tenant, string $code, array $input): array
    {
        $definition = $this->requireEnabled($tenant, $code);
        $known = array_column($definition['settings'], 'key');
        $unknown = array_diff(array_keys($input), $known);
        if ($unknown !== []) {
            throw ValidationException::withMessages([
                'settings' => ['Unknown setting: '.implode(', ', $unknown)],
            ]);
        }

        $values = $this->settings($tenant, $code);
        foreach ($definition['settings'] as $field) {
            if (! array_key_exists($field['key'], $input)) {
                continue;
            }
            $values[$field['key']] = $this->cast($field, $input[$field['key']]);
        }

        $settings = $tenant->settings ?? [];
        $bag = is_array($settings['module_settings'] ?? null) ? $settings['module_settings'] : [];
        $bag[$definition['code']] = $values;
        $settings['module_settings'] = $bag;
        $tenant->settings = $settings;
        $tenant->save();

        return $values;
    }

    /**
     * @return list<string>
     */
    public function setEnabled(Tenant $tenant, string $code, bool $enabled): array
    {
        $code = ModuleRegistry::canonical($code);
        if (ModuleRegistry::definition($code) === null) {
            throw ValidationException::withMessages([
                'code' => ['Unknown module.'],
            ]);
        }

        if ($enabled) {
            $plan = $this->planCodes($tenant);
            if ($plan !== [] && ! in_array($code, $plan, true)) {
                abort(403, 'Module disabled.');
            }
        }

        $current = $this->enabledCodes($tenant);
        $next = $enabled
            ? array_values(array_unique([...$current, $code]))
            : array_values(array_filter($current, fn (string $item) => $item !== $code));

        if ($next === []) {
            throw ValidationException::withMessages([
                'enabled' => ['At least one module must stay on.'],
            ]);
        }

        $next = array_values(array_filter(
            ModuleRegistry::CODES,
            fn (string $item) => in_array($item, $next, true),
        ));

        $settings = $tenant->settings ?? [];
        $saas = is_array($settings['saas'] ?? null) ? $settings['saas'] : [];
        $saas['modules'] = $next;
        $settings['saas'] = $saas;
        $tenant->settings = $settings;
        $tenant->save();

        return $next;
    }

    /**
     * @param  array<string, mixed>  $field
     */
    private function cast(array $field, mixed $value): bool|int|string
    {
        if ($field['type'] === 'boolean') {
            return filter_var($value, FILTER_VALIDATE_BOOLEAN);
        }

        if ($field['type'] === 'integer') {
            $number = (int) $value;

            return max(1, min(3650, $number));
        }

        $text = is_string($value) ? trim($value) : (string) $field['default'];
        if (isset($field['options']) && ! in_array($text, $field['options'], true)) {
            throw ValidationException::withMessages([
                $field['key'] => ['Invalid value.'],
            ]);
        }

        return mb_substr($text, 0, 120);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function settingFields(?Tenant $tenant, string $code): array
    {
        $definition = ModuleRegistry::definition($code);
        $values = $this->settings($tenant, $code);
        $fields = [];
        foreach ($definition['settings'] as $field) {
            $fields[] = [
                'key' => $field['key'],
                'type' => $field['type'],
                'value' => $values[$field['key']],
                'options' => $field['options'] ?? null,
            ];
        }

        return $fields;
    }

    /** @return array<string, mixed> */
    private function requireEnabled(?Tenant $tenant, string $code): array
    {
        $definition = ModuleRegistry::definition($code);
        if ($definition === null) {
            throw ValidationException::withMessages([
                'code' => ['Unknown module.'],
            ]);
        }
        if (! $this->isEnabled($definition['code'], $tenant)) {
            abort(403, 'Module disabled.');
        }

        return $definition;
    }
}
