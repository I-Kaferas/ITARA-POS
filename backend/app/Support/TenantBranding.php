<?php

namespace App\Support;

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
     *     marketing: array{hero_title: string, hero_subtitle: string, cta_label: string, cta_url: string}
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
            'primary_color' => self::hexOr($settings['primary_color'] ?? null, '#3D5C73'),
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
            'primary_color' => '#3D5C73',
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
