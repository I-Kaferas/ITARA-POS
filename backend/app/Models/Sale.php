<?php

namespace App\Models;

use App\Enums\SalePaymentStatus;
use App\Enums\SaleStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Sale extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'customer_id',
        'warehouse_id',
        'cash_register_id',
        'cashier_shift_id',
        'device_id',
        'processed_by',
        'reference',
        'status',
        'subtotal',
        'tax_total',
        'discount_total',
        'fees_total',
        'total',
        'paid_amount',
        'due_date',
        'payment_status',
        'currency',
        'payment_transaction_number',
        'idempotency_key',
        'completed_at',
        'notes',
        'table_id',
        'merged_into_id',
    ];

    protected function casts(): array
    {
        return [
            'status' => SaleStatus::class,
            'subtotal' => 'integer',
            'tax_total' => 'integer',
            'discount_total' => 'integer',
            'fees_total' => 'integer',
            'total' => 'integer',
            'paid_amount' => 'integer',
            'due_date' => 'date',
            'payment_status' => SalePaymentStatus::class,
            'completed_at' => 'datetime',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function diningTable(): BelongsTo
    {
        return $this->belongsTo(PosTable::class, 'table_id');
    }

    public function mergedInto(): BelongsTo
    {
        return $this->belongsTo(self::class, 'merged_into_id');
    }

    public function mergedSales(): HasMany
    {
        return $this->hasMany(self::class, 'merged_into_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
    }

    public function cashRegister(): BelongsTo
    {
        return $this->belongsTo(CashRegister::class);
    }

    public function cashierShift(): BelongsTo
    {
        return $this->belongsTo(CashierShift::class);
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(Device::class);
    }

    public function processedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'processed_by');
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(CustomerTransaction::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(SaleItem::class)->orderBy('sort_order');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(SalePayment::class)->orderBy('sort_order');
    }

    public function taxes(): HasMany
    {
        return $this->hasMany(SaleTax::class)->orderBy('sort_order');
    }

    public function discounts(): HasMany
    {
        return $this->hasMany(SaleDiscount::class)->orderBy('sort_order');
    }

    public function paymentTransactions(): HasMany
    {
        return $this->hasMany(PaymentTransaction::class);
    }

    public function returns(): HasMany
    {
        return $this->hasMany(SaleReturn::class)->orderByDesc('completed_at');
    }

    public function receipts(): HasMany
    {
        return $this->hasMany(SaleReceipt::class)->orderByDesc('printed_at');
    }

    public function syncEvents(): HasMany
    {
        return $this->hasMany(SyncEvent::class, 'entity_id')
            ->where('entity_type', 'sale')
            ->orderBy('sequence');
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(SaleInvoice::class)->orderByDesc('issued_at');
    }

    public function installments(): HasMany
    {
        return $this->hasMany(SaleInstallment::class)->orderBy('installment_number');
    }

    public function outstandingAmount(): int
    {
        return max(0, $this->total - $this->paid_amount);
    }

    public function isOnCredit(): bool
    {
        return $this->payment_status === SalePaymentStatus::OnCredit
            || $this->payment_status === SalePaymentStatus::Partial;
    }

    /** @return array<string, mixed> */
    public function toSummaryArray(): array
    {
        return [
            'id' => $this->id,
            'reference' => $this->reference,
            'status' => $this->status->value,
            'store_id' => $this->store_id,
            'customer_id' => $this->customer_id,
            'warehouse_id' => $this->warehouse_id,
            'subtotal' => $this->subtotal,
            'tax_total' => $this->tax_total,
            'discount_total' => $this->discount_total,
            'fees_total' => $this->fees_total,
            'total' => $this->total,
            'paid_amount' => $this->paid_amount,
            'outstanding_amount' => $this->outstandingAmount(),
            'due_date' => $this->due_date?->toDateString(),
            'payment_status' => $this->payment_status->value,
            'currency' => $this->currency,
            'payment_transaction_number' => $this->payment_transaction_number,
            'completed_at' => $this->completed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'table_id' => $this->table_id,
            'table' => $this->relationLoaded('diningTable') && $this->diningTable
                ? $this->diningTable->only(['id', 'name', 'code'])
                : null,
            'merged_into_id' => $this->merged_into_id,
            'merged_into' => $this->relationLoaded('mergedInto') && $this->mergedInto
                ? $this->mergedInto->only(['id', 'reference'])
                : null,
            'processed_by' => $this->relationLoaded('processedBy') && $this->processedBy
                ? $this->processedBy->only(['id', 'name'])
                : null,
            'customer' => $this->relationLoaded('customer') && $this->customer
                ? $this->customer->only(['id', 'name', 'email'])
                : null,
        ];
    }
}
