<?php

namespace App\Models;

use App\Enums\PaymentProviderType;
use App\Enums\PaymentTransactionStatus;
use App\Enums\PaymentTransactionType;
use App\Enums\SalePaymentMethod;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentTransaction extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'sale_id',
        'sale_return_id',
        'original_transaction_id',
        'transaction_number',
        'transaction_type',
        'payment_method',
        'amount',
        'currency',
        'status',
        'provider_type',
        'provider_reference',
        'idempotency_key',
        'customer_id',
        'cash_register_id',
        'processed_by',
        'metadata',
        'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'transaction_type' => PaymentTransactionType::class,
            'payment_method' => SalePaymentMethod::class,
            'status' => PaymentTransactionStatus::class,
            'provider_type' => PaymentProviderType::class,
            'metadata' => 'array',
            'completed_at' => 'datetime',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function saleReturn(): BelongsTo
    {
        return $this->belongsTo(SaleReturn::class);
    }

    public function originalTransaction(): BelongsTo
    {
        return $this->belongsTo(PaymentTransaction::class, 'original_transaction_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function cashRegister(): BelongsTo
    {
        return $this->belongsTo(CashRegister::class);
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
            'transaction_number' => $this->transaction_number,
            'transaction_type' => $this->transaction_type->value,
            'payment_method' => $this->payment_method->value,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'status' => $this->status->value,
            'provider_type' => $this->provider_type->value,
            'provider_reference' => $this->provider_reference,
            'original_transaction_id' => $this->original_transaction_id,
            'sale_return_id' => $this->sale_return_id,
            'metadata' => $this->metadata,
            'completed_at' => $this->completed_at?->toIso8601String(),
        ];
    }
}
