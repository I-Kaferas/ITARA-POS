<?php

namespace App\Services\Customer;

use App\Enums\CustomerPaymentMethod;
use App\Enums\CustomerPaymentStatus;
use App\Enums\CustomerTransactionType;
use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\CustomerTransaction;
use App\Models\Sale;
use App\Services\Sales\SaleCreditService;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CustomerLedgerService
{
    public function __construct(
        private readonly CustomerLoyaltyService $loyalty,
        private readonly SaleCreditService $saleCredit,
    ) {}

    /**
     * @param  array{
     *     transaction_type: CustomerTransactionType,
     *     amount: int,
     *     reference?: string|null,
     *     description?: string|null,
     *     due_date?: string|null,
     *     sale_id?: string|null,
     *     occurred_at?: \DateTimeInterface|null,
     *     recorded_by?: string|null,
     *     earn_loyalty?: bool,
     * }  $data
     */
    public function recordReceivable(Customer $customer, array $data): CustomerTransaction
    {
        $type = $data['transaction_type'];

        if (! $type->increasesReceivable()) {
            throw ValidationException::withMessages([
                'transaction_type' => ['Invalid receivable transaction type.'],
            ]);
        }

        if ($data['amount'] <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['Amount must be greater than zero.'],
            ]);
        }

        $this->assertCreditLimit($customer, $data['amount']);

        $dueDate = $data['due_date'] ?? (
            $customer->payment_terms_days > 0
                ? now()->addDays($customer->payment_terms_days)->toDateString()
                : null
        );

        $loyaltyDelta = 0;
        if ($type->earnsLoyalty() && ($data['earn_loyalty'] ?? true)) {
            $loyaltyDelta = $this->loyalty->pointsForAmount($data['amount']);
        }

        return DB::transaction(function () use ($customer, $data, $type, $dueDate, $loyaltyDelta): CustomerTransaction {
            $transaction = CustomerTransaction::query()->create([
                'tenant_id' => $customer->tenant_id,
                'customer_id' => $customer->id,
                'sale_id' => $data['sale_id'] ?? null,
                'transaction_type' => $type,
                'reference' => $data['reference'] ?? null,
                'amount' => $data['amount'],
                'paid_amount' => 0,
                'due_date' => $type->isReceivable() ? $dueDate : null,
                'loyalty_points_delta' => $loyaltyDelta,
                'description' => $data['description'] ?? null,
                'recorded_by' => $data['recorded_by'] ?? null,
                'occurred_at' => $data['occurred_at'] ?? now(),
            ]);

            if ($loyaltyDelta > 0) {
                $this->loyalty->applyEarnedPoints($customer, $loyaltyDelta);
            }

            return $transaction;
        });
    }

    public function recordSale(Customer $customer, Sale $sale, ?string $recordedBy = null): CustomerTransaction
    {
        if ($sale->customer_id !== $customer->id) {
            throw ValidationException::withMessages([
                'customer_id' => ['Sale does not belong to this customer.'],
            ]);
        }

        return $this->recordReceivable($customer, [
            'transaction_type' => CustomerTransactionType::Sale,
            'amount' => $sale->total,
            'reference' => $sale->reference,
            'description' => "Sale {$sale->reference}",
            'sale_id' => $sale->id,
            'occurred_at' => $sale->created_at,
            'recorded_by' => $recordedBy,
        ]);
    }

    public function recordSaleReturn(
        Customer $customer,
        int $amount,
        ?Sale $sale = null,
        ?string $reference = null,
        ?string $description = null,
        ?string $recordedBy = null,
    ): CustomerTransaction {
        if ($amount <= 0) {
            throw ValidationException::withMessages(['amount' => ['Amount must be greater than zero.']]);
        }

        return CustomerTransaction::query()->create([
            'tenant_id' => $customer->tenant_id,
            'customer_id' => $customer->id,
            'sale_id' => $sale?->id,
            'transaction_type' => CustomerTransactionType::SaleReturn,
            'reference' => $reference,
            'amount' => $amount,
            'description' => $description,
            'recorded_by' => $recordedBy,
            'occurred_at' => now(),
        ]);
    }

    public function recordCreditNote(Customer $customer, int $amount, ?string $reference = null, ?string $description = null, ?string $recordedBy = null): CustomerTransaction
    {
        if ($amount <= 0) {
            throw ValidationException::withMessages(['amount' => ['Amount must be greater than zero.']]);
        }

        return CustomerTransaction::query()->create([
            'tenant_id' => $customer->tenant_id,
            'customer_id' => $customer->id,
            'transaction_type' => CustomerTransactionType::CreditNote,
            'reference' => $reference,
            'amount' => $amount,
            'description' => $description,
            'recorded_by' => $recordedBy,
            'occurred_at' => now(),
        ]);
    }

    public function recordWalletRefund(
        Customer $customer,
        int $amount,
        ?Sale $sale = null,
        ?string $reference = null,
        ?string $description = null,
        ?string $recordedBy = null,
    ): CustomerTransaction {
        if ($amount <= 0) {
            throw ValidationException::withMessages(['amount' => ['Amount must be greater than zero.']]);
        }

        return CustomerTransaction::query()->create([
            'tenant_id' => $customer->tenant_id,
            'customer_id' => $customer->id,
            'sale_id' => $sale?->id,
            'transaction_type' => CustomerTransactionType::CreditNote,
            'reference' => $reference,
            'amount' => $amount,
            'description' => $description ?? "Wallet refund {$reference}",
            'recorded_by' => $recordedBy,
            'occurred_at' => now(),
        ]);
    }

    /**
     * @param  list<array{transaction_id: string, amount: int}>|null  $allocations
     */
    public function recordPayment(
        Customer $customer,
        int $amount,
        CustomerPaymentMethod $method = CustomerPaymentMethod::Cash,
        ?array $allocations = null,
        ?string $reference = null,
        ?string $notes = null,
        ?string $recordedBy = null,
        ?\DateTimeInterface $paidAt = null,
    ): CustomerPayment {
        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['Payment amount must be greater than zero.'],
            ]);
        }

        return DB::transaction(function () use ($customer, $amount, $method, $allocations, $reference, $notes, $recordedBy, $paidAt): CustomerPayment {
            $payment = CustomerPayment::query()->create([
                'tenant_id' => $customer->tenant_id,
                'customer_id' => $customer->id,
                'payment_number' => $this->nextPaymentNumber($customer->tenant_id),
                'amount' => $amount,
                'payment_method' => $method,
                'reference' => $reference,
                'notes' => $notes,
                'status' => CustomerPaymentStatus::Completed,
                'paid_at' => $paidAt ?? now(),
                'recorded_by' => $recordedBy,
            ]);

            $allocationResult = CustomerTransactionGuard::runAuthorized(function () use ($customer, $amount, $allocations): array {
                return $this->applyPaymentAllocations($customer, $amount, $allocations);
            });

            CustomerTransaction::query()->create([
                'tenant_id' => $customer->tenant_id,
                'customer_id' => $customer->id,
                'customer_payment_id' => $payment->id,
                'transaction_type' => CustomerTransactionType::Payment,
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

    /** Positive = customer owes us. Negative = customer has credit. */
    public function balance(Customer $customer): int
    {
        return (int) CustomerTransaction::query()
            ->where('customer_id', $customer->id)
            ->get()
            ->sum(fn (CustomerTransaction $tx) => $tx->signedAmount());
    }

    public function receivable(Customer $customer): int
    {
        return max(0, $this->balance($customer));
    }

    public function credit(Customer $customer): int
    {
        return max(0, -$this->balance($customer));
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function history(Customer $customer, ?\DateTimeInterface $from = null, ?\DateTimeInterface $to = null): array
    {
        $query = CustomerTransaction::query()
            ->where('customer_id', $customer->id)
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
                'loyalty_points_delta' => $tx->loyalty_points_delta,
            ];
        }

        return $lines;
    }

    /**
     * @return Collection<int, CustomerTransaction>
     */
    public function openReceivables(Customer $customer, bool $overdueOnly = false): Collection
    {
        return CustomerTransaction::query()
            ->where('customer_id', $customer->id)
            ->whereIn('transaction_type', [
                CustomerTransactionType::Sale,
                CustomerTransactionType::OpeningBalance,
            ])
            ->orderByRaw('due_date is null')
            ->orderBy('due_date')
            ->orderBy('occurred_at')
            ->get()
            ->filter(function (CustomerTransaction $tx) use ($overdueOnly): bool {
                if ($tx->outstandingAmount() <= 0) {
                    return false;
                }

                return $overdueOnly ? $tx->isOverdue() : true;
            })
            ->values();
    }

    /**
     * @return array<string, mixed>
     */
    public function summary(Customer $customer): array
    {
        $transactions = CustomerTransaction::query()->where('customer_id', $customer->id)->get();

        return [
            'customer_id' => $customer->id,
            'balance' => $this->balance($customer),
            'receivable' => $this->receivable($customer),
            'credit' => $this->credit($customer),
            'credit_limit' => $customer->effectiveCreditLimit(),
            'available_credit' => $this->availableCredit($customer),
            'total_sales' => (int) $transactions->where('transaction_type', CustomerTransactionType::Sale)->sum('amount'),
            'total_payments' => (int) $transactions->where('transaction_type', CustomerTransactionType::Payment)->sum('amount'),
            'loyalty_points' => $customer->loyalty_points,
            'loyalty_tier' => $customer->loyalty_tier,
            'open_invoices' => $this->openReceivables($customer)->count(),
            'overdue_invoices' => $this->openReceivables($customer, overdueOnly: true)->count(),
        ];
    }

    public function availableCredit(Customer $customer): ?int
    {
        $limit = $customer->effectiveCreditLimit();

        if ($limit === null || $limit === 0) {
            return null;
        }

        return max(0, $limit - $this->receivable($customer));
    }

    private function assertCreditLimit(Customer $customer, int $additionalAmount): void
    {
        $limit = $customer->effectiveCreditLimit();

        if ($limit === null || $limit === 0) {
            return;
        }

        if ($this->receivable($customer) + $additionalAmount > $limit) {
            throw ValidationException::withMessages([
                'amount' => ['Credit limit exceeded for this customer.'],
            ]);
        }
    }

    /**
     * @param  list<array{transaction_id: string, amount: int}>|null  $allocations
     * @return array{applied: int, allocations: list<array{transaction_id: string, amount: int}>}
     */
    private function applyPaymentAllocations(Customer $customer, int $amount, ?array $allocations): array
    {
        $remaining = $amount;
        $applied = [];

        if ($allocations !== null && $allocations !== []) {
            foreach ($allocations as $item) {
                $tx = CustomerTransaction::query()
                    ->where('customer_id', $customer->id)
                    ->whereKey($item['transaction_id'])
                    ->lockForUpdate()
                    ->firstOrFail();

                $apply = min($item['amount'], $tx->outstandingAmount(), $remaining);

                if ($apply <= 0) {
                    continue;
                }

                $tx->paid_amount += $apply;
                $tx->save();

                $this->syncSaleBalance($tx);

                $applied[] = ['transaction_id' => $tx->id, 'amount' => $apply];
                $remaining -= $apply;
            }
        } else {
            foreach ($this->openReceivables($customer) as $tx) {
                if ($remaining <= 0) {
                    break;
                }

                $apply = min($tx->outstandingAmount(), $remaining);
                $tx->paid_amount += $apply;
                $tx->save();

                $this->syncSaleBalance($tx);

                $applied[] = ['transaction_id' => $tx->id, 'amount' => $apply];
                $remaining -= $apply;
            }
        }

        return ['applied' => $amount, 'allocations' => $applied];
    }

    private function nextPaymentNumber(string $tenantId): string
    {
        $count = CustomerPayment::query()->where('tenant_id', $tenantId)->count();

        return 'CPY-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }

    private function syncSaleBalance(CustomerTransaction $transaction): void
    {
        if ($transaction->sale_id === null) {
            return;
        }

        $this->saleCredit->syncFromCustomerTransaction($transaction);
    }
}
