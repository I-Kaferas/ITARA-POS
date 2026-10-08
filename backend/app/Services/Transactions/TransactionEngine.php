<?php

namespace App\Services\Transactions;

use App\DTOs\Transactions\TransactionInput;
use App\Enums\SalePaymentStatus;
use App\Enums\TransactionPaymentStatus;
use App\Enums\TransactionStatus;
use App\Enums\TransactionType;
use App\Models\BranchExpense;
use App\Models\PaymentTransaction;
use App\Models\PurchaseInvoice;
use App\Models\Sale;
use App\Models\SaleRefund;
use App\Models\StockAdjustment;
use App\Models\StockTransfer;
use App\Models\Transaction;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class TransactionEngine
{
    public function record(TransactionInput $input): Transaction
    {
        if ($input->source !== null) {
            $existing = $this->findBySource($input->source, $input->type);

            if ($existing !== null) {
                return $this->syncExisting($existing, $input);
            }
        }

        if ($input->idempotencyKey !== null) {
            $existing = $this->findByIdempotencyKey($input->tenantId, $input->idempotencyKey);

            if ($existing !== null) {
                // Already processed — do not duplicate.
                return $existing;
            }
        }

        try {
            return DB::transaction(function () use ($input): Transaction {
                return Transaction::query()->create([
                    'tenant_id' => $input->tenantId,
                    'reference' => $input->reference ?? $this->nextReference($input->tenantId, $input->type),
                    'idempotency_key' => $input->idempotencyKey,
                    'branch_id' => $input->branchId,
                    'user_id' => $input->userId,
                    'type' => $input->type,
                    'date' => $input->date ?? now()->toDateString(),
                    'status' => $input->status,
                    'amount' => $input->amount,
                    'currency' => $input->currency,
                    'payment_status' => $input->paymentStatus ?? $input->type->defaultPaymentStatus(),
                    'source_type' => $input->source?->getMorphClass(),
                    'source_id' => $input->source?->getKey(),
                    'metadata' => $input->metadata,
                ]);
            });
        } catch (UniqueConstraintViolationException $exception) {
            if ($input->idempotencyKey !== null) {
                $existing = $this->findByIdempotencyKey($input->tenantId, $input->idempotencyKey);
                if ($existing !== null) {
                    return $existing;
                }
            }

            if ($input->source !== null) {
                $existing = $this->findBySource($input->source, $input->type);
                if ($existing !== null) {
                    return $existing;
                }
            }

            throw $exception;
        }
    }

    /** @param  array<string, mixed>  $data */
    public function recordFromArray(array $data): Transaction
    {
        return $this->record(TransactionInput::fromArray($data));
    }

    public function recordSale(Sale $sale): Transaction
    {
        $sale->loadMissing('store');

        return $this->record(new TransactionInput(
            tenantId: $sale->tenant_id,
            type: TransactionType::Sale,
            amount: (int) $sale->total,
            currency: strtoupper((string) ($sale->currency ?: 'FBU')),
            branchId: $sale->store?->branch_id,
            userId: $sale->processed_by,
            reference: $sale->reference,
            date: $sale->order_date?->toDateString()
                ?? $sale->completed_at?->toDateString()
                ?? now()->toDateString(),
            status: $this->mapSaleStatus($sale),
            paymentStatus: $sale->payment_status instanceof SalePaymentStatus
                ? TransactionPaymentStatus::fromSalePaymentStatus($sale->payment_status)
                : TransactionPaymentStatus::Unpaid,
            idempotencyKey: $sale->idempotency_key,
            source: $sale,
            metadata: [
                'store_id' => $sale->store_id,
                'customer_id' => $sale->customer_id,
                'paid_amount' => $sale->paid_amount,
            ],
        ));
    }

    public function recordPurchase(PurchaseInvoice $invoice): Transaction
    {
        $invoice->loadMissing('purchaseOrder');

        $paid = (int) $invoice->paid_amount;
        $total = (int) $invoice->total;

        return $this->record(new TransactionInput(
            tenantId: $invoice->tenant_id,
            type: TransactionType::Purchase,
            amount: $total,
            currency: 'FBU',
            branchId: $invoice->purchaseOrder?->branch_id,
            userId: $invoice->purchaseOrder?->created_by,
            reference: $invoice->invoice_number,
            date: $invoice->invoiced_at?->toDateString() ?? now()->toDateString(),
            status: TransactionStatus::Completed,
            paymentStatus: TransactionPaymentStatus::fromAmounts($total, $paid),
            source: $invoice,
            metadata: [
                'purchase_order_id' => $invoice->purchase_order_id,
                'supplier_id' => $invoice->supplier_id,
                'goods_receipt_id' => $invoice->goods_receipt_id,
                'paid_amount' => $paid,
            ],
        ));
    }

    public function recordPayment(PaymentTransaction $payment): Transaction
    {
        $payment->loadMissing('store');

        $status = match ($payment->status->value) {
            'completed' => TransactionStatus::Completed,
            'failed' => TransactionStatus::Cancelled,
            'cancelled' => TransactionStatus::Cancelled,
            default => TransactionStatus::Pending,
        };

        $ledgerAmount = (int) ($payment->amount_in_sale_currency ?? $payment->amount);
        $ledgerCurrency = strtoupper((string) ($payment->sale_currency ?: $payment->currency ?: 'FBU'));

        return $this->record(new TransactionInput(
            tenantId: $payment->tenant_id,
            type: TransactionType::Payment,
            amount: $ledgerAmount,
            currency: $ledgerCurrency,
            branchId: $payment->store?->branch_id,
            userId: $payment->processed_by,
            reference: null,
            date: $payment->completed_at?->toDateString() ?? now()->toDateString(),
            status: $status,
            paymentStatus: TransactionPaymentStatus::Paid,
            idempotencyKey: $payment->idempotency_key,
            source: $payment,
            metadata: [
                'sale_id' => $payment->sale_id,
                'transaction_number' => $payment->transaction_number,
                'payment_method' => $payment->payment_method->value,
                'provider_type' => $payment->provider_type->value,
                'payment_currency' => $payment->currency,
                'payment_amount' => $payment->amount,
            ],
        ));
    }

    public function recordRefund(SaleRefund $refund): Transaction
    {
        $refund->loadMissing('store');

        return $this->record(new TransactionInput(
            tenantId: $refund->tenant_id,
            type: TransactionType::Refund,
            amount: (int) $refund->amount,
            currency: strtoupper((string) ($refund->currency ?: 'FBU')),
            branchId: $refund->store?->branch_id,
            userId: $refund->processed_by,
            reference: $refund->refund_number,
            date: $refund->completed_at?->toDateString() ?? now()->toDateString(),
            status: TransactionStatus::Completed,
            paymentStatus: TransactionPaymentStatus::Paid,
            source: $refund,
            metadata: [
                'sale_id' => $refund->sale_id,
                'sale_return_id' => $refund->sale_return_id,
                'refund_method' => $refund->refund_method->value,
            ],
        ));
    }

    public function recordExpense(BranchExpense $expense): Transaction
    {
        return $this->record(new TransactionInput(
            tenantId: $expense->tenant_id,
            type: TransactionType::Expense,
            amount: (int) $expense->amount,
            currency: strtoupper((string) ($expense->currency_code ?: 'FBU')),
            branchId: $expense->branch_id,
            userId: $expense->recorded_by ?? $expense->user_id,
            reference: $expense->reference ?: null,
            date: $expense->occurred_on?->toDateString() ?? now()->toDateString(),
            status: TransactionStatus::Completed,
            paymentStatus: TransactionPaymentStatus::Paid,
            source: $expense,
            metadata: [
                'store_id' => $expense->store_id,
                'expense_category_id' => $expense->expense_category_id,
                'category' => $expense->category,
                'description' => $expense->description,
            ],
        ));
    }

    public function recordTransfer(StockTransfer $transfer): Transaction
    {
        $transfer->loadMissing(['sourceWarehouse', 'items']);

        return $this->record(new TransactionInput(
            tenantId: $transfer->tenant_id,
            type: TransactionType::Transfer,
            amount: 0,
            currency: 'FBU',
            branchId: $transfer->sourceWarehouse?->branch_id,
            userId: $transfer->approved_by ?? $transfer->requested_by,
            reference: $transfer->transfer_number,
            date: $transfer->received_at?->toDateString()
                ?? $transfer->shipped_at?->toDateString()
                ?? now()->toDateString(),
            status: TransactionStatus::Completed,
            paymentStatus: TransactionPaymentStatus::NotApplicable,
            source: $transfer,
            metadata: [
                'source_warehouse_id' => $transfer->source_warehouse_id,
                'destination_warehouse_id' => $transfer->destination_warehouse_id,
                'item_count' => $transfer->items->count(),
            ],
        ));
    }

    public function recordAdjustment(StockAdjustment $adjustment): Transaction
    {
        $adjustment->loadMissing(['warehouse', 'items']);

        $amount = $adjustment->items->sum(
            fn ($item) => (int) $item->quantity * (int) ($item->unit_cost ?? 0)
        );

        return $this->record(new TransactionInput(
            tenantId: $adjustment->tenant_id,
            type: TransactionType::Adjustment,
            amount: (int) $amount,
            currency: 'FBU',
            branchId: $adjustment->warehouse?->branch_id,
            userId: $adjustment->approved_by ?? $adjustment->performed_by,
            reference: $adjustment->adjustment_number,
            date: $adjustment->completed_at?->toDateString() ?? now()->toDateString(),
            status: TransactionStatus::Completed,
            paymentStatus: TransactionPaymentStatus::NotApplicable,
            source: $adjustment,
            metadata: [
                'warehouse_id' => $adjustment->warehouse_id,
                'movement_type' => $adjustment->movement_type->value,
                'reason' => $adjustment->reason,
                'item_count' => $adjustment->items->count(),
            ],
        ));
    }

    public function updateStatus(Transaction $transaction, TransactionStatus $status): Transaction
    {
        if ($transaction->status->isFinal() && $status !== $transaction->status) {
            throw ValidationException::withMessages([
                'status' => ['Final transactions cannot change status.'],
            ]);
        }

        $transaction->update(['status' => $status]);

        return $transaction->fresh();
    }

    public function updatePaymentStatus(
        Transaction $transaction,
        TransactionPaymentStatus $paymentStatus,
        ?int $amount = null,
    ): Transaction {
        $payload = ['payment_status' => $paymentStatus];

        if ($amount !== null) {
            $payload['amount'] = $amount;
        }

        $transaction->update($payload);

        return $transaction->fresh();
    }

    public function void(Transaction $transaction, ?string $reason = null): Transaction
    {
        $metadata = $transaction->metadata ?? [];
        if ($reason !== null) {
            $metadata['void_reason'] = $reason;
        }

        $transaction->update([
            'status' => TransactionStatus::Voided,
            'metadata' => $metadata,
        ]);

        return $transaction->fresh();
    }

    public function findBySource(Model $source, ?TransactionType $type = null): ?Transaction
    {
        $query = Transaction::query()
            ->where('source_type', $source->getMorphClass())
            ->where('source_id', $source->getKey());

        if ($type !== null) {
            $query->where('type', $type);
        }

        return $query->first();
    }

    public function findByReference(string $tenantId, string $reference): ?Transaction
    {
        return Transaction::query()
            ->where('tenant_id', $tenantId)
            ->where('reference', $reference)
            ->first();
    }

    public function findByIdempotencyKey(string $tenantId, string $key): ?Transaction
    {
        return Transaction::query()
            ->where('tenant_id', $tenantId)
            ->where('idempotency_key', $key)
            ->first();
    }

    private function syncExisting(Transaction $existing, TransactionInput $input): Transaction
    {
        $existing->update([
            'branch_id' => $input->branchId ?? $existing->branch_id,
            'user_id' => $input->userId ?? $existing->user_id,
            'date' => $input->date ?? $existing->date?->toDateString(),
            'status' => $input->status,
            'amount' => $input->amount,
            'currency' => $input->currency,
            'payment_status' => $input->paymentStatus ?? $existing->payment_status,
            'metadata' => $input->metadata ?? $existing->metadata,
        ]);

        return $existing->fresh();
    }

    private function mapSaleStatus(Sale $sale): TransactionStatus
    {
        return match ($sale->status->value) {
            'draft' => TransactionStatus::Draft,
            'pending' => TransactionStatus::Pending,
            'completed' => TransactionStatus::Completed,
            'voided' => TransactionStatus::Voided,
            'merged' => TransactionStatus::Cancelled,
            default => TransactionStatus::Pending,
        };
    }

    private function nextReference(string $tenantId, TransactionType $type): string
    {
        $prefix = $type->referencePrefix();

        Transaction::query()
            ->where('tenant_id', $tenantId)
            ->lockForUpdate()
            ->orderBy('id')
            ->limit(1)
            ->get(['id']);

        $max = 0;
        Transaction::query()
            ->where('tenant_id', $tenantId)
            ->where('reference', 'like', $prefix.'-%')
            ->pluck('reference')
            ->each(function (string $reference) use (&$max): void {
                if (preg_match('/(\d+)$/', $reference, $matches) === 1) {
                    $max = max($max, (int) $matches[1]);
                }
            });

        return $prefix.'-'.str_pad((string) ($max + 1), 6, '0', STR_PAD_LEFT);
    }
}
