<?php

namespace App\Models;

use App\Enums\SaleReturnRefundMethod;
use App\Enums\SaleReturnStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SaleReturn extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_id',
        'store_id',
        'warehouse_id',
        'customer_id',
        'return_number',
        'status',
        'reason',
        'refund_method',
        'subtotal',
        'tax_total',
        'discount_total',
        'total',
        'currency',
        'processed_by',
        'approved_by',
        'idempotency_key',
        'approved_at',
        'completed_at',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'status' => SaleReturnStatus::class,
            'refund_method' => SaleReturnRefundMethod::class,
            'subtotal' => 'integer',
            'tax_total' => 'integer',
            'discount_total' => 'integer',
            'total' => 'integer',
            'approved_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function processedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'processed_by');
    }

    public function approvedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function items(): HasMany
    {
        return $this->hasMany(SaleReturnItem::class)->orderBy('sort_order');
    }

    public function refunds(): HasMany
    {
        return $this->hasMany(SaleRefund::class)->orderByDesc('completed_at');
    }

    /** @return array<string, mixed> */
    public function toSummaryArray(): array
    {
        return [
            'id' => $this->id,
            'return_number' => $this->return_number,
            'sale_id' => $this->sale_id,
            'status' => $this->status->value,
            'reason' => $this->reason,
            'refund_method' => $this->refund_method->value,
            'subtotal' => $this->subtotal,
            'tax_total' => $this->tax_total,
            'discount_total' => $this->discount_total,
            'total' => $this->total,
            'currency' => $this->currency,
            'completed_at' => $this->completed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
