<?php

namespace App\Models;

use App\Enums\SupplierTransactionType;
use App\Models\Concerns\BelongsToTenant;
use App\Services\Supplier\SupplierTransactionGuard;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Validation\ValidationException;

class SupplierTransaction extends Model
{
    use BelongsToTenant, HasUuids;

    public const UPDATED_AT = null;

    protected $fillable = [
        'tenant_id',
        'supplier_id',
        'purchase_order_id',
        'supplier_payment_id',
        'transaction_type',
        'reference',
        'amount',
        'paid_amount',
        'due_date',
        'description',
        'recorded_by',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'transaction_type' => SupplierTransactionType::class,
            'amount' => 'integer',
            'paid_amount' => 'integer',
            'due_date' => 'date',
            'occurred_at' => 'datetime',
        ];
    }

    public static function booted(): void
    {
        static::updating(function (SupplierTransaction $transaction): void {
            if (SupplierTransactionGuard::isAuthorized()) {
                $dirty = array_keys($transaction->getDirty());

                if ($dirty === ['paid_amount']) {
                    return;
                }
            }

            throw ValidationException::withMessages([
                'supplier_transaction' => ['Supplier transactions are immutable.'],
            ]);
        });

        static::deleting(function (): void {
            throw ValidationException::withMessages([
                'supplier_transaction' => ['Supplier transactions cannot be deleted.'],
            ]);
        });
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function purchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class);
    }

    /** @deprecated Use purchaseOrder() */
    public function purchase(): BelongsTo
    {
        return $this->purchaseOrder();
    }

    public function supplierPayment(): BelongsTo
    {
        return $this->belongsTo(SupplierPayment::class);
    }

    public function recordedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    public function signedAmount(): int
    {
        return $this->transaction_type->increasesDebt() ? $this->amount : -$this->amount;
    }

    public function outstandingAmount(): int
    {
        if (! $this->transaction_type->isPayable()) {
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
