<?php

namespace App\Services\Platform;

use App\Models\Tenant;

class SaasCatalog
{
    /** @var list<string> */
    public const MODULES = ['pos', 'stock', 'restaurant', 'hotel'];

    /** @var list<string> */
    public const LIFECYCLE = ['trial', 'active', 'past_due', 'suspended', 'cancelled', 'archived'];

    /** @var array<string, list<string>> */
    public const PLANS = [
        'pos_stock' => ['pos', 'stock'],
        'pos_stock_restaurant' => ['pos', 'stock', 'restaurant'],
        'pos_stock_hotel_restaurant' => ['pos', 'stock', 'hotel', 'restaurant'],
    ];

    /** @var array<string, string> */
    private const COMMERCIAL_PLAN_ALIASES = [
        'starter' => 'starter',
        'professional' => 'professional',
        'enterprise' => 'enterprise',
        'pos_stock' => 'starter',
        'pos_stock_restaurant' => 'professional',
        'pos_stock_hotel_restaurant' => 'enterprise',
    ];

    /** @var array<string, int> */
    public const COMMERCIAL_RANK = [
        'starter' => 1,
        'professional' => 2,
        'enterprise' => 3,
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

    /** @return array{plan: string, status: string, billing_cycle: string, renews_on: ?string} */
    public function commercialSubscription(?Tenant $tenant): array
    {
        $saved = is_array($tenant?->settings['saas'] ?? null) ? $tenant->settings['saas'] : [];
        $subscription = is_array($saved['subscription'] ?? null) ? $saved['subscription'] : [];
        $rawPlan = $subscription['plan'] ?? null;
        $cycle = $subscription['billing_cycle'] ?? 'yearly';
        $status = $subscription['status'] ?? 'active';
        $renews = $subscription['renews_on'] ?? null;

        return [
            'plan' => $this->resolveCommercialPlan(is_string($rawPlan) ? $rawPlan : null, $tenant),
            'status' => in_array($status, ['active', 'trial', 'past_due', 'cancelled'], true) ? $status : 'active',
            'billing_cycle' => $cycle === 'monthly' ? 'monthly' : 'yearly',
            'renews_on' => is_string($renews) && $renews !== '' ? $renews : null,
        ];
    }

    private function resolveCommercialPlan(?string $plan, ?Tenant $tenant): string
    {
        if ($plan !== null && isset(self::COMMERCIAL_PLAN_ALIASES[$plan])) {
            return self::COMMERCIAL_PLAN_ALIASES[$plan];
        }

        $modules = $this->modules($tenant);
        if (in_array('hotel', $modules, true)) {
            return 'enterprise';
        }
        if (in_array('restaurant', $modules, true)) {
            return 'professional';
        }

        return 'starter';
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
