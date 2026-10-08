<?php

namespace App\Models;

use App\Modules\ModuleRegistry;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SaasPlan extends Model
{
    use HasUuids;

    protected $fillable = [
        'code',
        'name',
        'rank',
        'monthly_price',
        'yearly_price',
        'currency_code',
        'trial_days',
        'grace_days',
        'limits',
        'is_public',
    ];

    protected function casts(): array
    {
        return [
            'rank' => 'integer',
            'monthly_price' => 'integer',
            'yearly_price' => 'integer',
            'trial_days' => 'integer',
            'grace_days' => 'integer',
            'limits' => 'array',
            'is_public' => 'boolean',
        ];
    }

    public function priceFor(string $cycle): int
    {
        return $cycle === 'monthly' ? $this->monthly_price : $this->yearly_price;
    }

    public function limit(string $key): ?int
    {
        $value = $this->limits[$key] ?? null;

        return $value === null || $value === '' ? null : (int) $value;
    }

    /** @return list<string> */
    public function modules(): array
    {
        $modules = $this->limits['modules'] ?? [];

        return ModuleRegistry::normalize(is_array($modules) ? $modules : []);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(SaasSubscription::class, 'plan_code', 'code');
    }
}
