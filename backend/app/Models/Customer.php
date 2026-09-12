<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
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

    public function effectiveCreditLimit(): ?int
    {
        if ($this->credit_limit === 0) {
            return null;
        }

        return $this->credit_limit
            ?? (int) config('customers.default_credit_limit', 0);
    }
}
