<?php

namespace App\Services\Shifts;

use App\Enums\SalePaymentMethod;
use App\Enums\SaleStatus;
use App\Models\CashierShift;
use App\Models\CashRegisterSession;
use App\Models\Sale;
use App\Models\SalePayment;
use Illuminate\Support\Collection;

final class ShiftReportBuilder
{
    /**
     * @return array{
     *     invoices_count: int,
     *     invoices_total: int,
     *     invoices: list<array{reference: string, total: int, completed_at: mixed, currency: string|null}>,
     *     payment_methods: list<array{method: string, label: string, count: int, amount: int}>
     * }
     */
    public static function forCashierShift(CashierShift $shift): array
    {
        $sales = Sale::query()
            ->where('cashier_shift_id', $shift->id)
            ->where('status', SaleStatus::Completed)
            ->orderBy('completed_at')
            ->get(['id', 'reference', 'total', 'completed_at', 'currency']);

        return self::fromSales($sales);
    }

    /**
     * @return array{
     *     invoices_count: int,
     *     invoices_total: int,
     *     invoices: list<array{reference: string, total: int, completed_at: mixed, currency: string|null}>,
     *     payment_methods: list<array{method: string, label: string, count: int, amount: int}>
     * }
     */
    public static function forRegisterSession(CashRegisterSession $session): array
    {
        $shiftIds = CashierShift::query()
            ->where('cash_register_session_id', $session->id)
            ->pluck('id');

        $salesQuery = Sale::query()->where('status', SaleStatus::Completed);

        if ($shiftIds->isNotEmpty()) {
            $salesQuery->whereIn('cashier_shift_id', $shiftIds);
        } else {
            $salesQuery
                ->where('cash_register_id', $session->cash_register_id)
                ->where('completed_at', '>=', $session->opened_at);
            if ($session->closed_at !== null) {
                $salesQuery->where('completed_at', '<=', $session->closed_at);
            }
        }

        $sales = $salesQuery
            ->orderBy('completed_at')
            ->get(['id', 'reference', 'total', 'completed_at', 'currency']);

        return self::fromSales($sales);
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return array{
     *     invoices_count: int,
     *     invoices_total: int,
     *     invoices: list<array{reference: string, total: int, completed_at: mixed, currency: string|null}>,
     *     payment_methods: list<array{method: string, label: string, count: int, amount: int}>
     * }
     */
    private static function fromSales(Collection $sales): array
    {
        $payments = SalePayment::query()
            ->whereIn('sale_id', $sales->pluck('id'))
            ->get(['sale_id', 'payment_method', 'amount']);

        /** @var array<string, array{method: string, label: string, count: int, amount: int}> $byMethod */
        $byMethod = [];
        /** @var array<string, array<string, true>> $salesWithPayment */
        $salesWithPayment = [];

        foreach ($payments as $payment) {
            $method = (string) $payment->payment_method;
            if (! isset($byMethod[$method])) {
                $label = SalePaymentMethod::tryFrom($method)?->label() ?? $method;
                $byMethod[$method] = [
                    'method' => $method,
                    'label' => $label,
                    'count' => 0,
                    'amount' => 0,
                ];
            }
            $byMethod[$method]['amount'] += (int) $payment->amount;
            $salesWithPayment[(string) $payment->sale_id][$method] = true;
        }

        foreach (array_keys($byMethod) as $method) {
            $count = 0;
            foreach ($salesWithPayment as $methods) {
                if (isset($methods[$method])) {
                    $count++;
                }
            }
            $byMethod[$method]['count'] = $count;
        }

        return [
            'invoices_count' => $sales->count(),
            'invoices_total' => (int) $sales->sum('total'),
            'invoices' => $sales->map(fn (Sale $sale) => [
                'reference' => (string) $sale->reference,
                'total' => (int) $sale->total,
                'completed_at' => $sale->completed_at,
                'currency' => $sale->currency,
            ])->values()->all(),
            'payment_methods' => array_values($byMethod),
        ];
    }
}
