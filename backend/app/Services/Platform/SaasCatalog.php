<?php

namespace App\Services\Platform;

use App\Models\Tenant;

class SaasCatalog
{
    /** @var list<string> */
    public const MODULES = ['pos', 'stock', 'restaurant', 'hotel'];

    /** @var array<string, list<string>> */
    public const PLANS = [
        'pos_stock' => ['pos', 'stock'],
        'pos_stock_restaurant' => ['pos', 'stock', 'restaurant'],
        'pos_stock_hotel_restaurant' => ['pos', 'stock', 'hotel', 'restaurant'],
    ];

    /** @return list<string> */
    public function modules(?Tenant $tenant): array
    {
        $saved = $tenant?->settings['saas']['modules'] ?? null;
        if (! is_array($saved) || $saved === []) {
            return self::MODULES;
        }

        return array_values(array_intersect(self::MODULES, $saved));
    }

    /** @return array<string, mixed> */
    public function saas(?Tenant $tenant): array
    {
        $saved = is_array($tenant?->settings['saas'] ?? null) ? $tenant->settings['saas'] : [];
        $plan = $saved['subscription']['plan'] ?? null;

        return [
            'modules' => $this->modules($tenant),
            'modules_locked' => is_array($saved['modules'] ?? null) && $saved['modules'] !== [],
            'license' => [
                'key' => $saved['license']['key'] ?? null,
                'status' => $saved['license']['status'] ?? 'active',
                'seats' => (int) ($saved['license']['seats'] ?? 0),
                'expires_on' => $saved['license']['expires_on'] ?? null,
            ],
            'subscription' => [
                'plan' => is_string($plan) ? $plan : null,
                'status' => $saved['subscription']['status'] ?? 'active',
                'renews_on' => $saved['subscription']['renews_on'] ?? null,
            ],
            'support' => is_array($saved['support'] ?? null) ? $saved['support'] : [],
        ];
    }
}
