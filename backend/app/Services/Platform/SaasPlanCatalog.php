<?php

namespace App\Services\Platform;

use App\Modules\ModuleRegistry;

class SaasPlanCatalog
{
    /**
     * Prices are stored in USD cents. A null limit means unlimited.
     *
     * @return array<string, array<string, mixed>>
     */
    public static function definitions(): array
    {
        return [
            'starter' => [
                'name' => 'Starter',
                'rank' => 1,
                'monthly_price' => 700,
                'yearly_price' => 5000,
                'trial_days' => 14,
                'grace_days' => 7,
                'limits' => [
                    'users' => 5,
                    'branches' => 1,
                    'pos' => 2,
                    'products' => 1000,
                    'storage_mb' => 10240,
                    'transactions' => 2000,
                    'modules' => ['pos', 'inventory'],
                ],
            ],
            'professional' => [
                'name' => 'Professional',
                'rank' => 2,
                'monthly_price' => 1500,
                'yearly_price' => 10000,
                'trial_days' => 14,
                'grace_days' => 7,
                'limits' => [
                    'users' => 25,
                    'branches' => 5,
                    'pos' => 10,
                    'products' => 10000,
                    'storage_mb' => 102400,
                    'transactions' => 20000,
                    'modules' => ['pos', 'inventory', 'restaurant'],
                ],
            ],
            'business' => [
                'name' => 'Business',
                'rank' => 3,
                'monthly_price' => 3500,
                'yearly_price' => 35000,
                'trial_days' => 14,
                'grace_days' => 7,
                'limits' => [
                    'users' => 80,
                    'branches' => 20,
                    'pos' => 40,
                    'products' => 50000,
                    'storage_mb' => 512000,
                    'transactions' => 100000,
                    'modules' => ['pos', 'inventory', 'restaurant', 'hotel'],
                ],
            ],
            'enterprise' => [
                'name' => 'Enterprise',
                'rank' => 4,
                'monthly_price' => 7900,
                'yearly_price' => 79000,
                'trial_days' => 14,
                'grace_days' => 14,
                'limits' => [
                    'users' => null,
                    'branches' => null,
                    'pos' => null,
                    'products' => null,
                    'storage_mb' => null,
                    'transactions' => null,
                    'modules' => ModuleRegistry::CODES,
                ],
            ],
        ];
    }
}
