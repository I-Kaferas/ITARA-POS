<?php

namespace App\Models;

use App\Enums\CustomerTransactionType;
use App\Models\Concerns\BelongsToTenant;
use App\Services\Customer\CustomerTransactionGuard;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Validation\ValidationException;

class CustomerTransaction extends Model
{
    use BelongsToTenant, HasUuids;

    public const UPDATED_AT = null;

    protected $fillable = [
        'tenant_id',
        'customer_id',
        'sale_id',
        'customer_payment_id',
        'transaction_type',
        'reference',
        'amount',
        'paid_amount',
        'due_date',
        'loyalty_points_delta',
        'description',
        'recorded_by',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'transaction_type' => CustomerTransactionType::class,
            'amount' => 'integer',
            'paid_amount' => 'integer',
            'due_date' => 'date',
            'loyalty_points_delta' => 'integer',
            'occurred_at' => 'datetime',
        ];
    }

    public static function booted(): void
    {
        static::updating(function (CustomerTransaction $transaction): void {
            if (CustomerTransactionGuard::isAuthorized()) {
                if (array_keys($transaction->getDirty()) === ['paid_amount']) {
                    return;
                }
            }

            throw ValidationException::withMessages([
                'customer_transaction' => ['Customer transactions are immutable.'],
            ]);
        });

        static::deleting(function (): void {
            throw ValidationException::withMessages([
                'customer_transaction' => ['Customer transactions cannot be deleted.'],
            ]);
        });
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function customerPayment(): BelongsTo
    {
        return $this->belongsTo(CustomerPayment::class);
    }

    public function recordedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    public function signedAmount(): int
    {
        return $this->transaction_type->increasesReceivable() ? $this->amount : -$this->amount;
    }

    public function outstandingAmount(): int
    {
        if (! $this->transaction_type->isReceivable()) {
            return 0;
        }

        return max(0, $this->amount - $this->paid_amount);
    }

    public function isOverdue(): bool
    {
        return $this->due_date !== null
            && $this->due_date->isPast()
            && $this->outstandingAmount() > 0;
    }
}
