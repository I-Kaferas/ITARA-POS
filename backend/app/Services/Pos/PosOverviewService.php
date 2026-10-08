<?php

namespace App\Services\Pos;

use App\Enums\SalePaymentMethod;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SalePayment;
use App\Models\Store;
use App\Services\Performance\ReadCache;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class PosOverviewService
{
    /** @return array<string, mixed> */
    public function forStore(Store $store, Carbon $date): array
    {
        $day = $date->copy()->startOfDay();

        return app(ReadCache::class)->remember(
            'sales',
            'pos-overview:'.$store->id.':'.$day->toDateString(),
            fn () => $this->build($store, $day),
        );
    }

    /** @return array<string, mixed> */
    private function build(Store $store, Carbon $day): array
    {
        $end = $day->copy()->endOfDay();
        $sales = Sale::query()
            ->where('store_id', $store->id)
            ->where('status', 'completed')
            ->whereBetween('completed_at', [$day, $end]);

        $totals = (clone $sales)->toBase()->selectRaw(
            'COUNT(*) as sales_count, COALESCE(SUM(total), 0) as revenue, COALESCE(SUM(paid_amount), 0) as paid_amount'
        )->first();

        $salesCount = (int) $totals->sales_count;
        $revenue = (int) $totals->revenue;

        $recent = (clone $sales)
            ->with('customer:id,name,email')
            ->orderByDesc('completed_at')
            ->limit(8)
            ->get();

        return [
            'date' => $day->toDateString(),
            'store_id' => $store->id,
            'kpis' => [
                'sales_count' => $salesCount,
                'revenue' => $revenue,
                'paid_amount' => (int) $totals->paid_amount,
                'average_ticket' => $salesCount > 0 ? (int) round($revenue / $salesCount) : 0,
            ],
            'best_selling_products' => $salesCount > 0 ? $this->bestSellingProducts($store, $day, $end) : [],
            'recent_orders' => $recent->map(fn (Sale $sale) => $sale->toSummaryArray())->values(),
            'payment_methods' => $salesCount > 0 ? $this->paymentMethods($store, $day, $end) : [],
            'sales_by_hour' => $this->salesByHour($store, $day, $end),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function bestSellingProducts(Store $store, Carbon $start, Carbon $end): array
    {
        $saleIds = Sale::query()
            ->where('store_id', $store->id)
            ->where('status', 'completed')
            ->whereBetween('completed_at', [$start, $end])
            ->pluck('id');

        if ($saleIds->isEmpty()) {
            return [];
        }

        $items = SaleItem::query()
            ->whereIn('sale_id', $saleIds)
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
     * @return list<array<string, mixed>>
     */
    private function paymentMethods(Store $store, Carbon $start, Carbon $end): array
    {
        $rows = SalePayment::query()
            ->join('sales', 'sales.id', '=', 'sale_payments.sale_id')
            ->where('sales.store_id', $store->id)
            ->where('sales.status', 'completed')
            ->whereBetween('sales.completed_at', [$start, $end])
            ->whereNull('sales.deleted_at')
            ->selectRaw('sale_payments.payment_method as payment_method, SUM(sale_payments.amount) as amount, COUNT(*) as payment_count')
            ->groupBy('sale_payments.payment_method')
            ->get();

        $total = (int) $rows->sum(fn ($row) => (int) $row->amount);
        $grouped = $rows->map(function ($row) use ($total) {
            $amount = (int) $row->amount;
            $code = (string) $row->payment_method;

            return [
                'payment_method' => $code,
                'label' => $this->paymentLabel($code),
                'amount' => $amount,
                'count' => (int) $row->payment_count,
                'share' => $total > 0 ? (int) round($amount / $total * 100) : 0,
            ];
        })->sortByDesc('amount')->values()->all();

        return $grouped;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function salesByHour(Store $store, Carbon $start, Carbon $end): array
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

        $hourSql = DB::connection()->getDriverName() === 'sqlite'
            ? "CAST(strftime('%H', completed_at) AS INTEGER)"
            : 'HOUR(completed_at)';

        $rows = Sale::query()
            ->where('store_id', $store->id)
            ->where('status', 'completed')
            ->whereBetween('completed_at', [$start, $end])
            ->selectRaw($hourSql.' as hour_bucket, COUNT(*) as sales_count, COALESCE(SUM(total), 0) as revenue')
            ->groupBy(DB::raw($hourSql))
            ->get();

        foreach ($rows as $row) {
            $hour = (int) $row->hour_bucket;
            if (! isset($buckets[$hour])) {
                continue;
            }
            $buckets[$hour]['sales_count'] = (int) $row->sales_count;
            $buckets[$hour]['revenue'] = (int) $row->revenue;
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
            SalePaymentMethod::BankTransfer => 'Banque',
            SalePaymentMethod::Credit => 'Crédit',
            SalePaymentMethod::Wallet => 'Portefeuille',
            default => $code !== '' ? ucfirst(str_replace('_', ' ', $code)) : 'Autre',
        };
    }
}
