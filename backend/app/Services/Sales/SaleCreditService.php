<?php

namespace App\Services\Sales;

use App\Enums\SaleInstallmentStatus;
use App\Enums\SalePaymentStatus;
use App\Models\CustomerTransaction;
use App\Models\Sale;
use App\Models\SaleInstallment;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;

class SaleCreditService
{
    /**
     * @param  array{
     *     count?: int,
     *     first_due_date?: string,
     *     schedule?: list<array{amount: int, due_date: string}>,
     * }  $installmentData
     * @return list<SaleInstallment>
     */
    public function createInstallments(Sale $sale, int $creditAmount, array $installmentData): array
    {
        if ($creditAmount <= 0) {
            return [];
        }

        $schedule = $this->buildSchedule($creditAmount, $installmentData);

        $installments = [];

        foreach ($schedule as $index => $item) {
            $installments[] = SaleInstallment::query()->create([
                'tenant_id' => $sale->tenant_id,
                'sale_id' => $sale->id,
                'installment_number' => $index + 1,
                'amount' => $item['amount'],
                'paid_amount' => 0,
                'due_date' => $item['due_date'],
                'status' => SaleInstallmentStatus::Pending,
            ]);
        }

        return $installments;
    }

    public function syncFromCustomerTransaction(CustomerTransaction $transaction): void
    {
        if ($transaction->sale_id === null) {
            return;
        }

        $sale = Sale::query()->lockForUpdate()->find($transaction->sale_id);

        if ($sale === null) {
            return;
        }

        $immediatePaid = $sale->payments()
            ->whereNot('payment_method', 'credit')
            ->sum('amount');

        $creditPaid = $transaction->paid_amount;
        $sale->paid_amount = $immediatePaid + $creditPaid;
        $sale->payment_status = SalePaymentStatus::fromAmounts($sale->total, $sale->paid_amount);
        $sale->save();

        $this->syncInstallmentPayments($sale, $creditPaid);
    }

    public function applyCreditPayment(Sale $sale, int $amount): void
    {
        $remaining = $amount;

        foreach ($sale->installments()->orderBy('installment_number')->get() as $installment) {
            if ($remaining <= 0) {
                break;
            }

            $apply = min($installment->outstandingAmount(), $remaining);
            $installment->paid_amount += $apply;
            $installment->refreshStatus();
            $installment->save();
            $remaining -= $apply;
        }
    }

    private function syncInstallmentPayments(Sale $sale, int $creditPaid): void
    {
        if ($sale->installments()->count() === 0) {
            return;
        }

        $remaining = $creditPaid;

        foreach ($sale->installments()->orderBy('installment_number')->get() as $installment) {
            $apply = min($installment->amount, $remaining);
            $installment->paid_amount = $apply;
            $installment->refreshStatus();
            $installment->save();
            $remaining -= $apply;
        }
    }

    /**
     * @param  array{
     *     count?: int,
     *     first_due_date?: string,
     *     schedule?: list<array{amount: int, due_date: string}>,
     * }  $data
     * @return list<array{amount: int, due_date: string}>
     */
    private function buildSchedule(int $creditAmount, array $data): array
    {
        if (isset($data['schedule']) && $data['schedule'] !== []) {
            $schedule = $data['schedule'];
            $total = array_sum(array_column($schedule, 'amount'));

            if ($total !== $creditAmount) {
                throw ValidationException::withMessages([
                    'installments' => ["Installment schedule total ({$total}) must equal credit amount ({$creditAmount})."],
                ]);
            }

            return $schedule;
        }

        $count = max(1, (int) ($data['count'] ?? 1));
        $firstDueDate = isset($data['first_due_date'])
            ? Carbon::parse($data['first_due_date'])
            : now()->addMonth();

        $baseAmount = intdiv($creditAmount, $count);
        $remainder = $creditAmount - ($baseAmount * $count);
        $schedule = [];

        for ($i = 0; $i < $count; $i++) {
            $amount = $baseAmount + ($i === $count - 1 ? $remainder : 0);
            $schedule[] = [
                'amount' => $amount,
                'due_date' => $firstDueDate->copy()->addMonths($i)->toDateString(),
            ];
        }

        return $schedule;
    }
}
