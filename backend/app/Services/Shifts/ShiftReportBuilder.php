<?php

namespace App\Services\Shifts;

use App\Enums\SalePaymentMethod;
use App\Enums\SalePaymentStatus;
use App\Enums\SaleStatus;
use App\Models\CashierShift;
use App\Models\CashRegisterSession;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SalePayment;
use App\Models\StockBalance;
use Illuminate\Support\Collection;

final class ShiftReportBuilder
{
    /**
     * @return array{
     *     invoices_count: int,
     *     invoices_total: int,
     *     invoices: list<array{reference: string, total: int, completed_at: mixed, currency: string|null}>,
     *     payment_methods: list<array{method: string, label: string, count: int, amount: int}>,
     *     handover: array<string, mixed>
     * }
     */
    public static function forCashierShift(CashierShift $shift): array
    {
        $sales = Sale::query()
            ->with(['items.product', 'store'])
            ->where('cashier_shift_id', $shift->id)
            ->where('status', SaleStatus::Completed)
            ->orderBy('completed_at')
            ->get();

        return self::fromSales($sales);
    }

    /**
     * @return array{
     *     invoices_count: int,
     *     invoices_total: int,
     *     invoices: list<array{reference: string, total: int, completed_at: mixed, currency: string|null}>,
     *     payment_methods: list<array{method: string, label: string, count: int, amount: int}>,
     *     handover: array<string, mixed>
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
            ->with(['items.product', 'store'])
            ->orderBy('completed_at')
            ->get();

        return self::fromSales($sales);
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return array{
     *     invoices_count: int,
     *     invoices_total: int,
     *     invoices: list<array{reference: string, total: int, completed_at: mixed, currency: string|null}>,
     *     payment_methods: list<array{method: string, label: string, count: int, amount: int}>,
     *     handover: array<string, mixed>
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
            'handover' => self::handover($sales),
        ];
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return array<string, mixed>
     */
    private static function handover(Collection $sales): array
    {
        $productIds = $sales
            ->flatMap(fn (Sale $sale) => $sale->items->pluck('product_id'))
            ->filter()
            ->unique()
            ->values();

        /** @var array<string, int> $remaining */
        $remaining = [];
        if ($productIds->isNotEmpty()) {
            $balances = StockBalance::query()
                ->whereIn('product_id', $productIds)
                ->get(['product_id', 'quantity_on_hand']);
            foreach ($balances as $balance) {
                $key = (string) $balance->product_id;
                $remaining[$key] = ($remaining[$key] ?? 0) + (int) $balance->quantity_on_hand;
            }
        }

        /** @var array<string, array{id: string, name: string, lines: array<string, array{name: string, code: string, sold: int, credit_qty: int, remaining: int, total: int}>}> $stores */
        $stores = [];
        $articlesSold = 0;
        $articlesOnCredit = 0;
        $creditSalesTotal = 0;
        $creditOrders = 0;
        $currency = null;

        foreach ($sales as $sale) {
            $currency ??= $sale->currency;
            $onCredit = self::saleOnCredit($sale);
            if ($onCredit) {
                $creditOrders++;
                $creditSalesTotal += (int) $sale->total;
            }

            $storeId = (string) ($sale->store_id ?? '');
            $storeName = trim((string) ($sale->store?->name ?? ''));
            if ($storeName === '') {
                $storeName = 'Magasin';
            }
            if (! isset($stores[$storeId])) {
                $stores[$storeId] = [
                    'id' => $storeId,
                    'name' => $storeName,
                    'lines' => [],
                ];
            }

            foreach ($sale->items as $item) {
                $sold = (int) $item->quantity;
                if ($sold <= 0) {
                    continue;
                }
                $articlesSold += $sold;
                $creditQty = $onCredit ? $sold : 0;
                $articlesOnCredit += $creditQty;
                $productId = (string) ($item->product_id ?? '');
                $code = self::itemCode($item);
                $name = trim((string) ($item->product_name ?: $item->product?->name ?: 'Article'));
                $lineKey = $productId !== '' ? $productId : $name.'|'.$code;
                $lineTotal = (int) $item->line_total;
                if ($lineTotal <= 0) {
                    $lineTotal = (int) $item->unit_price * $sold;
                }

                if (! isset($stores[$storeId]['lines'][$lineKey])) {
                    $stores[$storeId]['lines'][$lineKey] = [
                        'name' => $name,
                        'code' => $code,
                        'sold' => 0,
                        'credit_qty' => 0,
                        'remaining' => $productId !== '' ? ($remaining[$productId] ?? 0) : 0,
                        'total' => 0,
                    ];
                }
                $stores[$storeId]['lines'][$lineKey]['sold'] += $sold;
                $stores[$storeId]['lines'][$lineKey]['credit_qty'] += $creditQty;
                $stores[$storeId]['lines'][$lineKey]['total'] += $lineTotal;
            }
        }

        $storeRows = [];
        foreach ($stores as $store) {
            $lines = array_values($store['lines']);
            if ($lines === []) {
                continue;
            }
            usort($lines, fn (array $a, array $b) => strcasecmp($a['name'], $b['name']));
            $storeRows[] = [
                'id' => $store['id'],
                'name' => $store['name'],
                'articles_count' => array_sum(array_column($lines, 'sold')),
                'lines' => $lines,
            ];
        }
        usort($storeRows, fn (array $a, array $b) => strcasecmp($a['name'], $b['name']));

        return [
            'articles_sold' => $articlesSold,
            'articles_on_credit' => $articlesOnCredit,
            'orders_count' => $sales->count(),
            'stores_count' => count($storeRows),
            'credit_sales_total' => $creditSalesTotal,
            'credit_orders_count' => $creditOrders,
            'currency' => $currency ?: 'USD',
            'stores' => $storeRows,
        ];
    }

    private static function saleOnCredit(Sale $sale): bool
    {
        if ((int) $sale->total <= 0) {
            return false;
        }

        $status = $sale->payment_status;

        return $status === SalePaymentStatus::OnCredit
            || $status === SalePaymentStatus::Partial
            || (int) $sale->paid_amount < (int) $sale->total;
    }

    private static function itemCode(SaleItem $item): string
    {
        $sku = trim((string) ($item->product_sku ?: $item->product?->sku ?: ''));

        return $sku;
    }
}
