<?php

namespace App\Models;

use App\Enums\SupplierPaymentMethod;
use App\Enums\SupplierPaymentStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class SupplierPayment extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'supplier_id',
        'payment_number',
        'amount',
        'payment_method',
        'reference',
        'notes',
        'status',
        'paid_at',
        'recorded_by',
        'allocations',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'payment_method' => SupplierPaymentMethod::class,
            'status' => SupplierPaymentStatus::class,
            'paid_at' => 'datetime',
            'allocations' => 'array',
        ];
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function recordedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(SupplierTransaction::class);
    }

    public function isVoid(): bool
    {
        return $this->status === SupplierPaymentStatus::Void;
    }
}
