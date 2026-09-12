<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Company extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'name',
        'trade_name',
        'legal_name',
        'legal_form',
        'tax_id',
        'registration_number',
        'phone',
        'email',
        'website',
        'logo_url',
        'currency_code',
        'address',
        'settings',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'address' => 'array',
            'settings' => 'array',
            'is_active' => 'boolean',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function branches(): HasMany
    {
        return $this->hasMany(Branch::class);
    }

    public function catalogs(): HasMany
    {
        return $this->hasMany(Catalog::class);
    }

    public function paymentMethods(): HasMany
    {
        return $this->hasMany(CompanyPaymentMethod::class)->orderBy('sort_order');
    }

    public function defaultCatalog(): ?Catalog
    {
        return $this->catalogs()->where('is_default', true)->first();
    }
}
