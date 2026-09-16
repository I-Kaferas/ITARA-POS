<?php

namespace App\Models;

use App\Enums\PurchaseRequisitionPriority;
use App\Enums\PurchaseRequisitionStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class PurchaseRequisition extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'branch_id',
        'warehouse_id',
        'supplier_id',
        'number',
        'status',
        'priority',
        'department',
        'needed_at',
        'reason',
        'notes',
        'rejection_comment',
        'subtotal',
        'tax_total',
        'total',
        'submitted_at',
        'approved_at',
        'rejected_at',
        'converted_at',
        'created_by',
        'submitted_by',
        'approved_by',
        'rejected_by',
        'converted_proforma_id',
        'converted_purchase_order_id',
    ];

    protected function casts(): array
    {
        return [
            'status' => PurchaseRequisitionStatus::class,
            'priority' => PurchaseRequisitionPriority::class,
            'needed_at' => 'date',
            'subtotal' => 'integer',
            'tax_total' => 'integer',
            'total' => 'integer',
            'submitted_at' => 'datetime',
            'approved_at' => 'datetime',
            'rejected_at' => 'datetime',
            'converted_at' => 'datetime',
        ];
    }

    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(PurchaseRequisitionItem::class)->orderBy('sort_order');
    }

    public function proformas(): HasMany
    {
        return $this->hasMany(PurchaseProforma::class);
    }

    public function purchaseOrders(): HasMany
    {
        return $this->hasMany(PurchaseOrder::class);
    }

    public function createdByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function approvedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function convertedProforma(): BelongsTo
    {
        return $this->belongsTo(PurchaseProforma::class, 'converted_proforma_id');
    }

    public function convertedPurchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class, 'converted_purchase_order_id');
    }

    public function refreshTotals(): void
    {
        $this->loadMissing('items');
        $subtotal = (int) $this->items->sum('line_total');
        $this->update([
            'subtotal' => $subtotal,
            'tax_total' => 0,
            'total' => $subtotal,
        ]);
    }
}
