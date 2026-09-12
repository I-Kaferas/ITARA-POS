<?php

namespace App\Models;

use App\Enums\PurchaseOrderStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class PurchaseOrder extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'branch_id',
        'supplier_id',
        'warehouse_id',
        'order_number',
        'reference',
        'status',
        'subtotal',
        'tax_total',
        'total',
        'due_date',
        'notes',
        'ordered_at',
        'expected_at',
        'submitted_at',
        'approved_at',
        'completed_at',
        'created_by',
        'approved_by',
    ];

    protected function casts(): array
    {
        return [
            'status' => PurchaseOrderStatus::class,
            'subtotal' => 'integer',
            'tax_total' => 'integer',
            'total' => 'integer',
            'due_date' => 'date',
            'ordered_at' => 'datetime',
            'expected_at' => 'datetime',
            'submitted_at' => 'datetime',
            'approved_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(PurchaseOrderItem::class)->orderBy('sort_order');
    }

    public function goodsReceipts(): HasMany
    {
        return $this->hasMany(GoodsReceipt::class);
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(PurchaseInvoice::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(SupplierTransaction::class);
    }

    public function createdByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function approvedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function isFullyReceived(): bool
    {
        $this->loadMissing('items');

        if ($this->items->isEmpty()) {
            return false;
        }

        return $this->items->every(fn (PurchaseOrderItem $item) => $item->quantity_received >= $item->quantity_ordered);
    }

    public function refreshTotals(): void
    {
        $this->loadMissing('items');

        $subtotal = (int) $this->items->sum('line_total');
        $this->update([
            'subtotal' => $subtotal,
            'total' => $subtotal + $this->tax_total,
        ]);
    }
}
