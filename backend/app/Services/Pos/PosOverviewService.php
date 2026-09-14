<?php

namespace App\Services\Pos;

use App\Enums\SalePaymentMethod;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SalePayment;
use App\Models\Store;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class PosOverviewService
{
    /** @return array<string, mixed> */
    public function forStore(Store $store, Carbon $date): array
    {
        $day = $date->copy()->startOfDay();

        $sales = Sale::query()
            ->where('store_id', $store->id)
            ->where('status', 'completed')
            ->whereBetween('completed_at', [$day, $day->copy()->endOfDay()])
            ->with('customer:id,name,email')
            ->orderByDesc('completed_at')
            ->get();

        $salesCount = $sales->count();
        $revenue = (int) $sales->sum('total');
        $paidAmount = (int) $sales->sum('paid_amount');

        return [
            'date' => $day->toDateString(),
            'store_id' => $store->id,
            'kpis' => [
                'sales_count' => $salesCount,
                'revenue' => $revenue,
                'paid_amount' => $paidAmount,
                'average_ticket' => $salesCount > 0 ? (int) round($revenue / $salesCount) : 0,
            ],
            'best_selling_products' => $this->bestSellingProducts($sales),
            'recent_orders' => $sales->take(8)->map(fn (Sale $sale) => $sale->toSummaryArray())->values(),
            'payment_methods' => $this->paymentMethods($sales),
            'sales_by_hour' => $this->salesByHour($sales),
        ];
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array<string, mixed>>
     */
    private function bestSellingProducts(Collection $sales): array
    {
        if ($sales->isEmpty()) {
            return [];
        }

        $items = SaleItem::query()
            ->whereIn('sale_id', $sales->pluck('id'))
            ->get(['product_id', 'product_name', 'product_sku', 'quantity', 'line_total']);

        $grouped = [];
        foreach ($items as $item) {
            $key = (string) ($item->product_id ?: ($item->product_sku ?: $item->product_name ?: 'article'));
            $grouped[$key] ??= [
                'product_id' => $item->product_id,
                'product_name' => $item->product_name ?: 'Article',
                'product_sku' => $item->product_sku,
                'quantity' => 0,
                'revenue' => 0,
            ];
            $grouped[$key]['quantity'] += (int) $item->quantity;
            $grouped[$key]['revenue'] += (int) $item->line_total;
        }

        $rows = array_values($grouped);
        usort($rows, fn (array $a, array $b) => $b['quantity'] <=> $a['quantity']);

        return array_slice($rows, 0, 8);
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array<string, mixed>>
     */
    private function paymentMethods(Collection $sales): array
    {
        if ($sales->isEmpty()) {
            return [];
        }

        $payments = SalePayment::query()
            ->whereIn('sale_id', $sales->pluck('id'))
            ->get(['payment_method', 'amount']);

        $grouped = [];
        foreach ($payments as $payment) {
            $code = (string) $payment->payment_method;
            $grouped[$code] ??= [
                'payment_method' => $code,
                'label' => $this->paymentLabel($code),
                'amount' => 0,
                'count' => 0,
            ];
            $grouped[$code]['amount'] += (int) $payment->amount;
            $grouped[$code]['count']++;
        }

        $total = array_sum(array_column($grouped, 'amount'));
        $rows = array_values($grouped);
        usort($rows, fn (array $a, array $b) => $b['amount'] <=> $a['amount']);

        return array_map(function (array $row) use ($total) {
            $row['share'] = $total > 0 ? (int) round($row['amount'] / $total * 100) : 0;

            return $row;
        }, $rows);
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array<string, mixed>>
     */
    private function salesByHour(Collection $sales): array
    {
        $buckets = [];
        for ($hour = 0; $hour < 24; $hour++) {
            $buckets[$hour] = [
                'hour' => $hour,
                'label' => sprintf('%02d:00', $hour),
                'sales_count' => 0,
                'revenue' => 0,
            ];
        }

        foreach ($sales as $sale) {
            $hour = (int) ($sale->completed_at?->format('G') ?? 0);
            $buckets[$hour]['sales_count']++;
            $buckets[$hour]['revenue'] += (int) $sale->total;
        }

        return array_values($buckets);
    }

    private function paymentLabel(string $code): string
    {
        $method = SalePaymentMethod::tryFrom($code);

        return match ($method) {
            SalePaymentMethod::Cash => 'Espèces',
            SalePaymentMethod::MobileMoney => 'Mobile Money',
            SalePaymentMethod::Card => 'Carte',
            SalePaymentMethod::BankTransfer => 'Virement',
            SalePaymentMethod::Credit => 'Crédit',
            SalePaymentMethod::Wallet => 'Portefeuille',
            default => $code !== '' ? ucfirst(str_replace('_', ' ', $code)) : 'Autre',
        };
    }
}
