<?php

namespace App\Models;

use App\Enums\PurchaseProformaStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class PurchaseProforma extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'branch_id',
        'warehouse_id',
        'supplier_id',
        'purchase_requisition_id',
        'number',
        'status',
        'payment_terms',
        'delivery_terms',
        'expires_at',
        'notes',
        'rejection_comment',
        'subtotal',
        'tax_total',
        'total',
        'sent_at',
        'reviewed_at',
        'approved_at',
        'rejected_at',
        'converted_at',
        'created_by',
        'sent_by',
        'reviewed_by',
        'approved_by',
        'rejected_by',
        'converted_purchase_order_id',
    ];

    protected function casts(): array
    {
        return [
            'status' => PurchaseProformaStatus::class,
            'expires_at' => 'date',
            'subtotal' => 'integer',
            'tax_total' => 'integer',
            'total' => 'integer',
            'sent_at' => 'datetime',
            'reviewed_at' => 'datetime',
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

    public function requisition(): BelongsTo
    {
        return $this->belongsTo(PurchaseRequisition::class, 'purchase_requisition_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(PurchaseProformaItem::class)->orderBy('sort_order');
    }

    public function purchaseOrders(): HasMany
    {
        return $this->hasMany(PurchaseOrder::class);
    }

    public function convertedPurchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class, 'converted_purchase_order_id');
    }

    public function createdByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function approvedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function isExpired(): bool
    {
        if ($this->status === PurchaseProformaStatus::Expired) {
            return true;
        }

        if ($this->expires_at === null) {
            return false;
        }

        if (in_array($this->status, [PurchaseProformaStatus::Approved, PurchaseProformaStatus::Converted], true)) {
            return false;
        }

        return $this->expires_at->endOfDay()->isPast();
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
