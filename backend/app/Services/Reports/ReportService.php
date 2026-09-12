<?php

namespace App\Services\Reports;

use App\Models\AccountingEntry;
use App\Models\InventoryAlert;
use App\Models\Sale;
use App\Models\SaleReturn;
use App\Models\StockBalance;
use App\Models\Store;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class ReportService
{
    /** @return array<string, mixed> */
    public function salesSummary(?string $storeId, ?Carbon $from, ?Carbon $to): array
    {
        $query = Sale::query()->where('status', 'completed');

        if ($storeId) {
            $query->where('store_id', $storeId);
        }

        if ($from) {
            $query->where('completed_at', '>=', $from->copy()->startOfDay());
        }

        if ($to) {
            $query->where('completed_at', '<=', $to->copy()->endOfDay());
        }

        $sales = (clone $query)->get();

        $byDay = (clone $query)
            ->select(
                DB::raw('DATE(completed_at) as day'),
                DB::raw('COUNT(*) as sales_count'),
                DB::raw('SUM(total) as revenue'),
                DB::raw('SUM(tax_total) as tax_total'),
                DB::raw('SUM(discount_total) as discount_total'),
            )
            ->groupBy(DB::raw('DATE(completed_at)'))
            ->orderBy('day')
            ->get()
            ->map(fn ($row) => [
                'day' => $row->day,
                'sales_count' => (int) $row->sales_count,
                'revenue' => (int) $row->revenue,
                'tax_total' => (int) $row->tax_total,
                'discount_total' => (int) $row->discount_total,
            ]);

        $returnsQuery = SaleReturn::query()->where('status', 'completed');
        if ($storeId) {
            $returnsQuery->where('store_id', $storeId);
        }
        if ($from) {
            $returnsQuery->where('created_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $returnsQuery->where('created_at', '<=', $to->copy()->endOfDay());
        }

        return [
            'sales_count' => $sales->count(),
            'revenue' => (int) $sales->sum('total'),
            'subtotal' => (int) $sales->sum('subtotal'),
            'tax_total' => (int) $sales->sum('tax_total'),
            'discount_total' => (int) $sales->sum('discount_total'),
            'paid_amount' => (int) $sales->sum('paid_amount'),
            'outstanding_amount' => (int) $sales->sum(fn (Sale $s) => max(0, $s->total - $s->paid_amount)),
            'returns_count' => $returnsQuery->count(),
            'returns_total' => (int) (clone $returnsQuery)->sum('total'),
            'by_day' => $byDay,
        ];
    }

    /** @return array<string, mixed> */
    public function inventorySummary(?string $warehouseId): array
    {
        $query = StockBalance::query()->with(['product:id,sku,name,cost_price', 'warehouse:id,name,code']);

        if ($warehouseId) {
            $query->where('warehouse_id', $warehouseId);
        }

        $balances = $query->get();
        $lowStock = InventoryAlert::query()
            ->where('status', '!=', 'resolved')
            ->when($warehouseId, fn ($q) => $q->where('warehouse_id', $warehouseId))
            ->count();

        $totalValue = $balances->sum(function (StockBalance $balance) {
            $cost = (int) ($balance->product?->cost_price ?? 0);

            return $cost * (int) $balance->quantity_on_hand;
        });

        return [
            'skus_in_stock' => $balances->where('quantity_on_hand', '>', 0)->count(),
            'total_units' => (int) $balances->sum('quantity_on_hand'),
            'total_available' => (int) $balances->sum('quantity_available'),
            'estimated_value' => $totalValue,
            'open_alerts' => $lowStock,
            'top_items' => $balances
                ->sortByDesc('quantity_on_hand')
                ->take(20)
                ->values()
                ->map(fn (StockBalance $b) => [
                    'product_id' => $b->product_id,
                    'sku' => $b->product?->sku,
                    'name' => $b->product?->name,
                    'warehouse' => $b->warehouse?->name,
                    'quantity_on_hand' => (int) $b->quantity_on_hand,
                    'quantity_available' => (int) $b->quantity_available,
                ]),
        ];
    }

    /** @return array<string, mixed> */
    public function financialSummary(?Carbon $from, ?Carbon $to): array
    {
        $query = AccountingEntry::query();

        if ($from) {
            $query->where('occurred_at', '>=', $from->copy()->startOfDay());
        }

        if ($to) {
            $query->where('occurred_at', '<=', $to->copy()->endOfDay());
        }

        $byAccount = (clone $query)
            ->select('account_code', DB::raw('SUM(debit) as total_debit'), DB::raw('SUM(credit) as total_credit'))
            ->groupBy('account_code')
            ->orderBy('account_code')
            ->get()
            ->map(fn ($row) => [
                'account_code' => $row->account_code,
                'total_debit' => (int) $row->total_debit,
                'total_credit' => (int) $row->total_credit,
                'net' => (int) $row->total_debit - (int) $row->total_credit,
            ]);

        $revenue = (int) (clone $query)->where('account_code', '4000')->sum('credit')
            - (int) (clone $query)->where('account_code', '4000')->sum('debit');
        $cogs = (int) (clone $query)->where('account_code', '5000')->sum('debit')
            - (int) (clone $query)->where('account_code', '5000')->sum('credit');
        $tax = (int) (clone $query)->where('account_code', '2200')->sum('credit')
            - (int) (clone $query)->where('account_code', '2200')->sum('debit');

        return [
            'total_debit' => (int) (clone $query)->sum('debit'),
            'total_credit' => (int) (clone $query)->sum('credit'),
            'revenue' => $revenue,
            'cogs' => $cogs,
            'gross_margin' => $revenue - $cogs,
            'tax_liability' => $tax,
            'by_account' => $byAccount,
        ];
    }

    /** @return list<array<string, mixed>> */
    public function salesByStore(?Carbon $from, ?Carbon $to): array
    {
        $stores = Store::query()->orderBy('name')->get(['id', 'name', 'code']);

        return $stores->map(function (Store $store) use ($from, $to) {
            $summary = $this->salesSummary($store->id, $from, $to);

            return [
                'store_id' => $store->id,
                'store_name' => $store->name,
                'store_code' => $store->code,
                'sales_count' => $summary['sales_count'],
                'revenue' => $summary['revenue'],
            ];
        })->values()->all();
    }
}
