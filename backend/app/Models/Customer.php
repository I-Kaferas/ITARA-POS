<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'code',
        'name',
        'company_name',
        'tax_id',
        'email',
        'phone',
        'date_of_birth',
        'gender',
        'credit_limit',
        'payment_terms_days',
        'loyalty_points',
        'loyalty_tier',
        'notes',
        'metadata',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'date_of_birth' => 'date',
            'credit_limit' => 'integer',
            'payment_terms_days' => 'integer',
            'loyalty_points' => 'integer',
            'metadata' => 'array',
            'is_active' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Customer $customer): void {
            $code = is_string($customer->code) ? trim($customer->code) : '';
            if ($code !== '') {
                $customer->code = $code;

                return;
            }

            $tenantId = (string) ($customer->tenant_id ?: app('tenant.id'));
            $customer->code = static::nextCode($tenantId);
        });
    }

    public static function nextCode(string $tenantId): string
    {
        $max = 0;
        $codes = static::withoutGlobalScopes()
            ->withTrashed()
            ->where('tenant_id', $tenantId)
            ->whereNotNull('code')
            ->where('code', 'like', 'CLI-%')
            ->pluck('code');

        foreach ($codes as $code) {
            if (is_string($code) && preg_match('/^CLI-(\d+)$/', $code, $matches) === 1) {
                $max = max($max, (int) $matches[1]);
            }
        }

        $candidate = '';
        $attempts = 0;
        do {
            $attempts++;
            $max++;
            $candidate = 'CLI-'.str_pad((string) $max, 4, '0', STR_PAD_LEFT);
        } while (
            $attempts < 1000
            && static::withoutGlobalScopes()
                ->withTrashed()
                ->where('tenant_id', $tenantId)
                ->where('code', $candidate)
                ->exists()
        );

        return $candidate;
    }

    public function addresses(): HasMany
    {
        return $this->hasMany(CustomerAddress::class)->orderByDesc('is_primary');
    }

    public function primaryAddress(): ?CustomerAddress
    {
        return $this->addresses()->where('is_primary', true)->first()
            ?? $this->addresses()->first();
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(CustomerTransaction::class)->orderByDesc('occurred_at');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(CustomerPayment::class)->orderByDesc('paid_at');
    }

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
    }

    public function effectivePriceTier(): string
    {
        $tier = $this->getAttribute('price_tier');

        return is_string($tier) && $tier !== '' ? $tier : 'retail';
    }

    public function effectiveCreditLimit(): ?int
    {
        if ($this->credit_limit === 0) {
            return null;
        }

        return $this->credit_limit
            ?? (int) config('customers.default_credit_limit', 0);
    }
}
