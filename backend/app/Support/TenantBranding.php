<?php

namespace App\Support;

use App\Models\Company;
use App\Models\Tenant;

final class TenantBranding
{
    /**
     * @return array{
     *     tenant_id: string,
     *     slug: string,
     *     status: string,
     *     brand_name: string,
     *     tagline: string,
     *     logo_url: string|null,
     *     primary_color: string,
     *     accent_color: string,
     *     support_email: string|null,
     *     support_phone: string|null,
     *     marketing: array{hero_title: string, hero_subtitle: string, cta_label: string, cta_url: string},
     *     company: array{
     *         name: string,
     *         trade_name: string|null,
     *         phone: string|null,
     *         email: string|null,
     *         website: string|null,
     *         logo_url: string|null,
     *         currency_code: string|null,
     *         activity_sector: string|null,
     *         legal_form: string|null,
     *         tax_id: string|null,
     *         registration_number: string|null,
     *         fiscal_center: string|null,
     *         opening_hours: string|null,
     *         address: string|null
     *     }|null
     * }
     */
    public static function from(Tenant $tenant): array
    {
        $settings = is_array($tenant->settings) ? $tenant->settings : [];
        $marketing = is_array($settings['marketing'] ?? null) ? $settings['marketing'] : [];

        $brandName = self::stringOr($settings['brand_name'] ?? null, $tenant->name);

        return [
            'tenant_id' => (string) $tenant->id,
            'slug' => (string) $tenant->slug,
            'status' => (string) $tenant->status,
            'brand_name' => $brandName,
            'tagline' => self::stringOr($settings['tagline'] ?? null, 'Point de vente professionnel'),
            'logo_url' => self::nullableString($settings['logo_url'] ?? null),
            'primary_color' => self::hexOr($settings['primary_color'] ?? null, '#12243C'),
            'accent_color' => self::hexOr($settings['accent_color'] ?? null, '#E39B2B'),
            'support_email' => self::nullableString($settings['support_email'] ?? null),
            'support_phone' => self::nullableString($settings['support_phone'] ?? null),
            'marketing' => [
                'hero_title' => self::stringOr($marketing['hero_title'] ?? null, $brandName),
                'hero_subtitle' => self::stringOr(
                    $marketing['hero_subtitle'] ?? null,
                    'Vendez plus vite, suivez vos stocks et pilotez votre magasin depuis un seul endroit.',
                ),
                'cta_label' => self::stringOr($marketing['cta_label'] ?? null, 'Ouvrir l’espace admin'),
                'cta_url' => self::stringOr($marketing['cta_url'] ?? null, ''),
            ],
            'company' => self::publicCompany($tenant),
        ];
    }

    /**
     * Public identity shown on the login brand panel. Sourced from company settings.
     *
     * @return array{
     *     name: string,
     *     trade_name: string|null,
     *     phone: string|null,
     *     email: string|null,
     *     website: string|null,
     *     logo_url: string|null,
     *     currency_code: string|null,
     *     activity_sector: string|null,
     *     legal_form: string|null,
     *     tax_id: string|null,
     *     registration_number: string|null,
     *     fiscal_center: string|null,
     *     opening_hours: string|null,
     *     address: string|null
     * }|null
     */
    private static function publicCompany(Tenant $tenant): ?array
    {
        $company = Company::query()
            ->where('tenant_id', $tenant->id)
            ->where('is_active', true)
            ->oldest()
            ->first()
            ?? Company::query()
                ->where('tenant_id', $tenant->id)
                ->oldest()
                ->first();

        if ($company === null) {
            return null;
        }

        $address = is_array($company->address) ? $company->address : [];
        $settings = is_array($company->settings) ? $company->settings : [];
        $parts = array_values(array_filter([
            self::nullableString($address['number'] ?? null),
            self::nullableString($address['avenue'] ?? null),
            self::nullableString($address['street'] ?? null),
            self::nullableString($address['quarter'] ?? null),
            self::nullableString($address['commune'] ?? null),
            self::nullableString($address['city'] ?? null),
            self::nullableString($address['province'] ?? $address['state'] ?? null),
            self::nullableString($address['postal_code'] ?? null),
            self::nullableString($address['country'] ?? null),
        ]));

        return [
            'name' => (string) $company->name,
            'trade_name' => self::nullableString($company->trade_name),
            'phone' => self::nullableString($company->phone),
            'email' => self::nullableString($company->email),
            'website' => self::nullableString($company->website),
            'logo_url' => self::nullableString($company->logo_url),
            'currency_code' => self::nullableString($company->currency_code),
            'activity_sector' => self::nullableString($settings['activity_sector'] ?? null),
            'legal_form' => self::nullableString($company->legal_form),
            'tax_id' => self::nullableString($company->tax_id),
            'registration_number' => self::nullableString($company->registration_number),
            'fiscal_center' => self::nullableString($settings['fiscal_center'] ?? null),
            'opening_hours' => self::nullableString($settings['opening_hours'] ?? null),
            'address' => $parts === [] ? null : implode(', ', $parts),
        ];
    }

    /**
     * Merge validated branding fields into tenant settings.
     *
     * @param  array<string, mixed>  $incoming
     * @return array<string, mixed>
     */
    public static function mergeSettings(array $current, array $incoming): array
    {
        $next = $current;

        foreach (['brand_name', 'tagline', 'logo_url', 'primary_color', 'accent_color', 'support_email', 'support_phone'] as $key) {
            if (array_key_exists($key, $incoming)) {
                $next[$key] = $incoming[$key];
            }
        }

        if (isset($incoming['marketing']) && is_array($incoming['marketing'])) {
            $existing = is_array($next['marketing'] ?? null) ? $next['marketing'] : [];
            $next['marketing'] = array_merge($existing, $incoming['marketing']);
        }

        return $next;
    }

    /**
     * @return array<string, mixed>
     */
    public static function demoSettings(string $brandName = 'Demo Boutique'): array
    {
        return [
            'brand_name' => $brandName,
            'tagline' => 'Caisse, stock et ventes — un POS pour chaque magasin',
            'logo_url' => null,
            'primary_color' => '#12243C',
            'accent_color' => '#E39B2B',
            'support_email' => 'contact@maboutique.local',
            'support_phone' => '+25722200000',
            'marketing' => [
                'hero_title' => $brandName,
                'hero_subtitle' => 'Vendez en caisse, suivez le stock et pilotez votre activité en temps réel.',
                'cta_label' => 'Accéder à l’admin',
                'cta_url' => '',
            ],
        ];
    }

    private static function stringOr(mixed $value, string $fallback): string
    {
        if (! is_string($value)) {
            return $fallback;
        }
        $trimmed = trim($value);

        return $trimmed === '' ? $fallback : $trimmed;
    }

    private static function nullableString(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }
        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private static function hexOr(mixed $value, string $fallback): string
    {
        if (! is_string($value)) {
            return $fallback;
        }
        $trimmed = trim($value);
        if (preg_match('/^#([0-9A-Fa-f]{6})$/', $trimmed) !== 1) {
            return $fallback;
        }

        return strtoupper($trimmed);
    }
}
