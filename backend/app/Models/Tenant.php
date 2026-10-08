<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Tenant extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'name',
        'legal_name',
        'trade_name',
        'slug',
        'logo_url',
        'address',
        'phone',
        'email',
        'website',
        'country_code',
        'currency_code',
        'timezone',
        'locale',
        'tax_regime',
        'tax_id',
        'registration_number',
        'settings',
        'subscription',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'address' => 'array',
            'settings' => 'array',
            'subscription' => 'array',
        ];
    }

    /** @return array<string, mixed> */
    public function profile(): array
    {
        return [
            'id' => $this->id,
            'legal_name' => $this->legal_name ?: $this->name,
            'trade_name' => $this->trade_name ?: $this->name,
            'logo_url' => $this->logo_url,
            'address' => $this->address,
            'phone' => $this->phone,
            'email' => $this->email,
            'website' => $this->website,
            'country_code' => $this->country_code,
            'currency_code' => $this->currency_code,
            'timezone' => $this->timezone,
            'locale' => $this->locale,
            'tax_regime' => $this->tax_regime,
            'tax_id' => $this->tax_id,
            'registration_number' => $this->registration_number,
            'settings' => $this->settings,
            'subscription' => $this->subscription ?: ($this->settings['saas']['subscription'] ?? null),
            'status' => $this->status,
            'created_at' => $this->created_at,
        ];
    }

    public function companies(): HasMany
    {
        return $this->hasMany(Company::class);
    }

    public function branches(): HasMany
    {
        return $this->hasMany(Branch::class);
    }

    public function stores(): HasMany
    {
        return $this->hasMany(Store::class);
    }

    public function warehouses(): HasMany
    {
        return $this->hasMany(Warehouse::class);
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class);
    }

    public function suppliers(): HasMany
    {
        return $this->hasMany(Supplier::class);
    }

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
    }

    public function purchases(): HasMany
    {
        return $this->hasMany(Purchase::class);
    }
}
