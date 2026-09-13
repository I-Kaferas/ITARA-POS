<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Supplier extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'name',
        'legal_name',
        'code',
        'tax_id',
        'email',
        'phone',
        'address',
        'payment_terms_days',
        'credit_limit',
        'currency_code',
        'notes',
        'metadata',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'address' => 'array',
            'payment_terms_days' => 'integer',
            'credit_limit' => 'integer',
            'metadata' => 'array',
            'is_active' => 'boolean',
        ];
    }

    public function contacts(): HasMany
    {
        return $this->hasMany(SupplierContact::class)->orderByDesc('is_primary')->orderBy('name');
    }

    public function primaryContact(): ?SupplierContact
    {
        return $this->contacts()->where('is_primary', true)->first()
            ?? $this->contacts()->first();
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(SupplierTransaction::class)->orderByDesc('occurred_at');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(SupplierPayment::class)->orderByDesc('paid_at');
    }

    public function products(): BelongsToMany
    {
        return $this->belongsToMany(Product::class, 'product_supplier')
            ->withPivot(['supplier_sku', 'cost_price'])
            ->withTimestamps();
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(PurchaseInvoice::class)->orderByDesc('invoiced_at');
    }

    public function purchaseOrders(): HasMany
    {
        return $this->hasMany(PurchaseOrder::class);
    }

    /** @deprecated Use purchaseOrders() */
    public function purchases(): HasMany
    {
        return $this->purchaseOrders();
    }
}
