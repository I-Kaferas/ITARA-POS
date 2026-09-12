<?php

namespace App\Models;

use App\Enums\SaleRefundStatus;
use App\Enums\SaleReturnRefundMethod;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleRefund extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_return_id',
        'sale_id',
        'store_id',
        'refund_number',
        'refund_method',
        'amount',
        'currency',
        'status',
        'payment_transaction_id',
        'customer_transaction_id',
        'cash_register_id',
        'original_payment_transaction_id',
        'processed_by',
        'metadata',
        'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'refund_method' => SaleReturnRefundMethod::class,
            'status' => SaleRefundStatus::class,
            'amount' => 'integer',
            'metadata' => 'array',
            'completed_at' => 'datetime',
        ];
    }

    public function saleReturn(): BelongsTo
    {
        return $this->belongsTo(SaleReturn::class);
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function paymentTransaction(): BelongsTo
    {
        return $this->belongsTo(PaymentTransaction::class);
    }

    public function customerTransaction(): BelongsTo
    {
        return $this->belongsTo(CustomerTransaction::class);
    }

    public function cashRegister(): BelongsTo
    {
        return $this->belongsTo(CashRegister::class);
    }

    public function originalPaymentTransaction(): BelongsTo
    {
        return $this->belongsTo(PaymentTransaction::class, 'original_payment_transaction_id');
    }

    public function processedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'processed_by');
    }

    /** @return array<string, mixed> */
    public function toSummaryArray(): array
    {
        return [
            'id' => $this->id,
            'refund_number' => $this->refund_number,
            'sale_return_id' => $this->sale_return_id,
            'sale_id' => $this->sale_id,
            'refund_method' => $this->refund_method->value,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'status' => $this->status->value,
            'payment_transaction_id' => $this->payment_transaction_id,
            'customer_transaction_id' => $this->customer_transaction_id,
            'cash_register_id' => $this->cash_register_id,
            'original_payment_transaction_id' => $this->original_payment_transaction_id,
            'metadata' => $this->metadata,
            'completed_at' => $this->completed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
