<?php

namespace App\Models;

use App\Enums\PurchaseInvoiceStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PurchaseInvoice extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'purchase_order_id',
        'goods_receipt_id',
        'supplier_id',
        'supplier_transaction_id',
        'invoice_number',
        'supplier_invoice_number',
        'status',
        'subtotal',
        'tax_total',
        'total',
        'paid_amount',
        'due_date',
        'invoiced_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => PurchaseInvoiceStatus::class,
            'subtotal' => 'integer',
            'tax_total' => 'integer',
            'total' => 'integer',
            'paid_amount' => 'integer',
            'due_date' => 'date',
            'invoiced_at' => 'datetime',
        ];
    }

    public function purchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class);
    }

    public function goodsReceipt(): BelongsTo
    {
        return $this->belongsTo(GoodsReceipt::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function supplierTransaction(): BelongsTo
    {
        return $this->belongsTo(SupplierTransaction::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(PurchasePayment::class);
    }

    public function outstandingAmount(): int
    {
        return max(0, $this->total - $this->paid_amount);
    }
}
