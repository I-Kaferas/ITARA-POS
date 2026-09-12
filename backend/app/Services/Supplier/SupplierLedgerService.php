<?php

namespace App\Services\Supplier;

use App\Enums\SupplierPaymentMethod;
use App\Enums\SupplierPaymentStatus;
use App\Enums\SupplierTransactionType;
use App\Models\Purchase;
use App\Models\PurchaseOrder;
use App\Models\Supplier;
use App\Models\SupplierPayment;
use App\Models\SupplierTransaction;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SupplierLedgerService
{
    /**
     * Record a payable (purchase invoice, debit note, opening balance).
     *
     * @param  array{
     *     transaction_type: SupplierTransactionType,
     *     amount: int,
     *     reference?: string|null,
     *     description?: string|null,
     *     due_date?: string|null,
     *     purchase_order_id?: string|null,
     *     occurred_at?: \DateTimeInterface|null,
     *     recorded_by?: string|null,
     * }  $data
     */
    public function recordPayable(Supplier $supplier, array $data): SupplierTransaction
    {
        $type = $data['transaction_type'];

        if (! $type->increasesDebt()) {
            throw ValidationException::withMessages([
                'transaction_type' => ['Invalid payable transaction type.'],
            ]);
        }

        if ($data['amount'] <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['Amount must be greater than zero.'],
            ]);
        }

        $dueDate = $data['due_date'] ?? now()->addDays($supplier->payment_terms_days)->toDateString();

        return SupplierTransaction::query()->create([
            'tenant_id' => $supplier->tenant_id,
            'supplier_id' => $supplier->id,
            'purchase_order_id' => $data['purchase_order_id'] ?? null,
            'transaction_type' => $type,
            'reference' => $data['reference'] ?? null,
            'amount' => $data['amount'],
            'paid_amount' => 0,
            'due_date' => $type->isPayable() ? $dueDate : null,
            'description' => $data['description'] ?? null,
            'recorded_by' => $data['recorded_by'] ?? null,
            'occurred_at' => $data['occurred_at'] ?? now(),
        ]);
    }

    /**
     * Record purchase and link ledger entry.
     */
    public function recordPurchaseOrder(Supplier $supplier, PurchaseOrder $purchaseOrder, ?string $recordedBy = null): SupplierTransaction
    {
        if ($purchaseOrder->supplier_id !== $supplier->id) {
            throw ValidationException::withMessages([
                'supplier_id' => ['Purchase order does not belong to this supplier.'],
            ]);
        }

        return $this->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => $purchaseOrder->total,
            'reference' => $purchaseOrder->order_number,
            'description' => "Purchase order {$purchaseOrder->order_number}",
            'due_date' => $purchaseOrder->due_date?->toDateString(),
            'purchase_order_id' => $purchaseOrder->id,
            'occurred_at' => $purchaseOrder->created_at,
            'recorded_by' => $recordedBy,
        ]);
    }

    /** @deprecated Use recordPurchaseOrder() */
    public function recordPurchase(Supplier $supplier, Purchase $purchase, ?string $recordedBy = null): SupplierTransaction
    {
        return $this->recordPurchaseOrder($supplier, $purchase, $recordedBy);
    }

    /**
     * Record credit note (reduces balance).
     */
    public function recordCreditNote(Supplier $supplier, int $amount, ?string $reference = null, ?string $description = null, ?string $recordedBy = null): SupplierTransaction
    {
        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['Amount must be greater than zero.'],
            ]);
        }

        return SupplierTransaction::query()->create([
            'tenant_id' => $supplier->tenant_id,
            'supplier_id' => $supplier->id,
            'transaction_type' => SupplierTransactionType::CreditNote,
            'reference' => $reference,
            'amount' => $amount,
            'description' => $description,
            'recorded_by' => $recordedBy,
            'occurred_at' => now(),
        ]);
    }

    /**
     * @param  list<array{transaction_id: string, amount: int}>|null  $allocations
     */
    public function recordPayment(
        Supplier $supplier,
        int $amount,
        SupplierPaymentMethod $method = SupplierPaymentMethod::BankTransfer,
        ?array $allocations = null,
        ?string $reference = null,
        ?string $notes = null,
        ?string $recordedBy = null,
        ?\DateTimeInterface $paidAt = null,
    ): SupplierPayment {
        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['Payment amount must be greater than zero.'],
            ]);
        }

        return DB::transaction(function () use ($supplier, $amount, $method, $allocations, $reference, $notes, $recordedBy, $paidAt): SupplierPayment {
            $payment = SupplierPayment::query()->create([
                'tenant_id' => $supplier->tenant_id,
                'supplier_id' => $supplier->id,
                'payment_number' => $this->nextPaymentNumber($supplier->tenant_id),
                'amount' => $amount,
                'payment_method' => $method,
                'reference' => $reference,
                'notes' => $notes,
                'status' => SupplierPaymentStatus::Completed,
                'paid_at' => $paidAt ?? now(),
                'recorded_by' => $recordedBy,
            ]);

            $allocationResult = SupplierTransactionGuard::runAuthorized(function () use ($supplier, $payment, $amount, $allocations): array {
                return $this->applyPaymentAllocations($supplier, $payment, $amount, $allocations);
            });

            SupplierTransaction::query()->create([
                'tenant_id' => $supplier->tenant_id,
                'supplier_id' => $supplier->id,
                'supplier_payment_id' => $payment->id,
                'transaction_type' => SupplierTransactionType::Payment,
                'reference' => $payment->payment_number,
                'amount' => $amount,
                'description' => $notes ?? "Payment {$payment->payment_number}",
                'recorded_by' => $recordedBy,
                'occurred_at' => $payment->paid_at,
            ]);

            $payment->update(['allocations' => $allocationResult['allocations']]);

            return $payment->fresh(['transactions']);
        });
    }

    public function balance(Supplier $supplier): int
    {
        return (int) SupplierTransaction::query()
            ->where('supplier_id', $supplier->id)
            ->get()
            ->sum(fn (SupplierTransaction $tx) => $tx->signedAmount());
    }

    /** Positive = we owe (debt), negative = supplier credit */
    public function debt(Supplier $supplier): int
    {
        return max(0, $this->balance($supplier));
    }

    public function credit(Supplier $supplier): int
    {
        return max(0, -$this->balance($supplier));
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function statement(Supplier $supplier, ?\DateTimeInterface $from = null, ?\DateTimeInterface $to = null): array
    {
        $query = SupplierTransaction::query()
            ->where('supplier_id', $supplier->id)
            ->orderBy('occurred_at')
            ->orderBy('created_at');

        if ($from) {
            $query->where('occurred_at', '>=', $from);
        }

        if ($to) {
            $query->where('occurred_at', '<=', $to);
        }

        $running = 0;
        $lines = [];

        foreach ($query->get() as $tx) {
            $running += $tx->signedAmount();
            $lines[] = [
                'id' => $tx->id,
                'occurred_at' => $tx->occurred_at->toIso8601String(),
                'transaction_type' => $tx->transaction_type->value,
                'reference' => $tx->reference,
                'description' => $tx->description,
                'debit' => $tx->signedAmount() > 0 ? $tx->amount : 0,
                'credit' => $tx->signedAmount() < 0 ? $tx->amount : 0,
                'balance' => $running,
                'due_date' => $tx->due_date?->toDateString(),
                'outstanding' => $tx->outstandingAmount(),
            ];
        }

        return $lines;
    }

    /**
     * @return Collection<int, SupplierTransaction>
     */
    public function dueTransactions(Supplier $supplier, bool $overdueOnly = false): Collection
    {
        return SupplierTransaction::query()
            ->where('supplier_id', $supplier->id)
            ->whereIn('transaction_type', [
                SupplierTransactionType::Purchase,
                SupplierTransactionType::DebitNote,
                SupplierTransactionType::OpeningBalance,
            ])
            ->whereNotNull('due_date')
            ->orderBy('due_date')
            ->get()
            ->filter(function (SupplierTransaction $tx) use ($overdueOnly): bool {
                if ($tx->outstandingAmount() <= 0) {
                    return false;
                }

                return $overdueOnly ? $tx->isOverdue() : true;
            })
            ->values();
    }

    /**
     * @return array{supplier: Supplier, balance: int, debt: int, credit: int, total_purchases: int, total_payments: int}
     */
    public function summary(Supplier $supplier): array
    {
        $transactions = SupplierTransaction::query()->where('supplier_id', $supplier->id)->get();

        return [
            'supplier_id' => $supplier->id,
            'balance' => $this->balance($supplier),
            'debt' => $this->debt($supplier),
            'credit' => $this->credit($supplier),
            'total_purchases' => (int) $transactions
                ->where('transaction_type', SupplierTransactionType::Purchase)
                ->sum('amount'),
            'total_payments' => (int) $transactions
                ->where('transaction_type', SupplierTransactionType::Payment)
                ->sum('amount'),
            'open_invoices' => $this->dueTransactions($supplier)->count(),
            'overdue_invoices' => $this->dueTransactions($supplier, overdueOnly: true)->count(),
        ];
    }

    /**
     * @param  list<array{transaction_id: string, amount: int}>|null  $allocations
     * @return array{applied: int, allocations: list<array{transaction_id: string, amount: int}>}
     */
    private function applyPaymentAllocations(
        Supplier $supplier,
        SupplierPayment $payment,
        int $amount,
        ?array $allocations,
    ): array {
        $remaining = $amount;
        $applied = [];

        if ($allocations !== null && $allocations !== []) {
            foreach ($allocations as $item) {
                $tx = SupplierTransaction::query()
                    ->where('supplier_id', $supplier->id)
                    ->whereKey($item['transaction_id'])
                    ->lockForUpdate()
                    ->firstOrFail();

                $apply = min($item['amount'], $tx->outstandingAmount(), $remaining);

                if ($apply <= 0) {
                    continue;
                }

                $tx->paid_amount += $apply;
                $tx->save();

                $applied[] = ['transaction_id' => $tx->id, 'amount' => $apply];
                $remaining -= $apply;
            }
        } else {
            $open = $this->dueTransactions($supplier);

            foreach ($open as $tx) {
                if ($remaining <= 0) {
                    break;
                }

                $apply = min($tx->outstandingAmount(), $remaining);
                $tx->paid_amount += $apply;
                $tx->save();

                $applied[] = ['transaction_id' => $tx->id, 'amount' => $apply];
                $remaining -= $apply;
            }
        }

        if ($remaining > 0) {
            // Unallocated payment becomes supplier credit (handled via signed balance)
            // No extra transaction needed — payment transaction uses full amount
        }

        return ['applied' => $amount, 'allocations' => $applied];
    }

    private function nextPaymentNumber(string $tenantId): string
    {
        $count = SupplierPayment::query()->where('tenant_id', $tenantId)->count();

        return 'SPY-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
