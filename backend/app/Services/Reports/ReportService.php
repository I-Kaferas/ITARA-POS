<?php

namespace App\Services\Reports;

use App\Models\AccountingEntry;
use App\Models\Expense;
use App\Models\InventoryAlert;
use App\Models\InventoryMovement;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SaleReturn;
use App\Models\StockBalance;
use App\Models\Store;
use App\Models\User;
use App\Services\Payable\PayableService;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class ReportService
{
    public function __construct(private readonly PayableService $payables) {}

    /** @return array<string, mixed> */
    public function salesSummary(?string $storeId, ?Carbon $from, ?Carbon $to, bool $breakdowns = true): array
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
            'by_week' => $breakdowns ? $this->groupSales($sales, 'week') : [],
            'by_month' => $breakdowns ? $this->groupSales($sales, 'month') : [],
            'by_year' => $breakdowns ? $this->groupSales($sales, 'year') : [],
            ...($breakdowns ? $this->salesDimensions($sales) : [
                'by_product' => [],
                'by_category' => [],
                'by_cashier' => [],
            ]),
        ];
    }

    /** @return array<string, mixed> */
    public function inventorySummary(?string $warehouseId, ?Carbon $from = null, ?Carbon $to = null): array
    {
        $query = StockBalance::query()->with(['product:id,sku,name,cost_price,low_stock_threshold', 'warehouse:id,name,code']);

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
            'low_stock' => ($lowStockRows = $balances
                ->filter(function (StockBalance $balance) {
                    $threshold = (int) ($balance->product?->low_stock_threshold ?? config('inventory.default_low_stock_threshold', 10));

                    return (int) $balance->quantity_on_hand <= $threshold;
                })
                ->sortBy('quantity_on_hand'))
                ->take(40)
                ->values()
                ->map(fn (StockBalance $b) => [
                    'product_id' => $b->product_id,
                    'sku' => $b->product?->sku,
                    'name' => $b->product?->name,
                    'warehouse' => $b->warehouse?->name,
                    'quantity_on_hand' => (int) $b->quantity_on_hand,
                    'threshold' => (int) ($b->product?->low_stock_threshold ?? config('inventory.default_low_stock_threshold', 10)),
                ])
                ->all(),
            'low_stock_count' => $lowStockRows->count(),
            'movements' => $this->stockMovements($warehouseId, $from, $to, lossesOnly: false),
            'losses' => $this->stockMovements($warehouseId, $from, $to, lossesOnly: true),
            'losses_value' => $this->lossValue($warehouseId, $from, $to),
            'expiration' => $this->expiringStock($warehouseId),
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

        $operations = $this->operationalFinance($from, $to);
        if ($revenue === 0 && $operations['revenue'] > 0) {
            $revenue = $operations['revenue'];
            $cogs = $operations['cogs'];
        }
        $expenses = $operations['expenses'];
        $margin = $revenue - $cogs;

        return [
            'total_debit' => (int) (clone $query)->sum('debit'),
            'total_credit' => (int) (clone $query)->sum('credit'),
            'revenue' => $revenue,
            'cogs' => $cogs,
            'gross_margin' => $margin,
            'expenses' => $expenses,
            'profit' => $margin - $expenses,
            'credit' => $operations['credit'],
            'debts' => $operations['debts'],
            'tax_liability' => $tax,
            'by_account' => $byAccount,
        ];
    }

    /** @return list<array<string, mixed>> */
    public function salesByStore(?Carbon $from, ?Carbon $to): array
    {
        $stores = Store::query()->orderBy('name')->get(['id', 'name', 'code']);

        return $stores->map(function (Store $store) use ($from, $to) {
            $summary = $this->salesSummary($store->id, $from, $to, false);

            return [
                'store_id' => $store->id,
                'store_name' => $store->name,
                'store_code' => $store->code,
                'sales_count' => $summary['sales_count'],
                'revenue' => $summary['revenue'],
            ];
        })->values()->all();
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array{label: string, sales_count: int, revenue: int}>
     */
    private function groupSales(Collection $sales, string $grain): array
    {
        return $sales
            ->groupBy(function (Sale $sale) use ($grain) {
                $at = $sale->completed_at;
                if ($at === null) {
                    return '—';
                }

                return match ($grain) {
                    'week' => $at->format('o-\WW'),
                    'month' => $at->format('Y-m'),
                    'year' => $at->format('Y'),
                    default => $at->toDateString(),
                };
            })
            ->map(fn (Collection $group, string $label) => [
                'label' => $label,
                'sales_count' => $group->count(),
                'revenue' => (int) $group->sum('total'),
            ])
            ->sortBy('label')
            ->values()
            ->all();
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return array{by_product: list<array<string, mixed>>, by_category: list<array<string, mixed>>, by_cashier: list<array<string, mixed>>}
     */
    private function salesDimensions(Collection $sales): array
    {
        if ($sales->isEmpty() || ! Schema::hasTable('sale_items')) {
            return ['by_product' => [], 'by_category' => [], 'by_cashier' => []];
        }

        $items = SaleItem::query()
            ->whereIn('sale_id', $sales->pluck('id'))
            ->with(['product:id,name,sku,category_id', 'product.category:id,name'])
            ->get(['id', 'sale_id', 'product_id', 'product_name', 'product_sku', 'quantity', 'line_total']);

        $products = [];
        $categories = [];
        foreach ($items as $item) {
            $productKey = $item->product_id ?: ($item->product_name ?: 'article');
            $products[$productKey] ??= [
                'label' => $item->product?->name ?? $item->product_name ?? $productKey,
                'sku' => $item->product?->sku ?? $item->product_sku,
                'quantity' => 0,
                'revenue' => 0,
            ];
            $products[$productKey]['quantity'] += (int) $item->quantity;
            $products[$productKey]['revenue'] += (int) $item->line_total;

            $category = $item->product?->category?->name;
            $categoryKey = $category ?: '';
            $categories[$categoryKey] ??= [
                'label' => $category,
                'quantity' => 0,
                'revenue' => 0,
            ];
            $categories[$categoryKey]['quantity'] += (int) $item->quantity;
            $categories[$categoryKey]['revenue'] += (int) $item->line_total;
        }

        $names = User::query()
            ->whereIn('id', $sales->pluck('processed_by')->filter()->unique()->all())
            ->pluck('name', 'id');
        $cashiers = [];
        foreach ($sales as $sale) {
            $id = (string) ($sale->processed_by ?? '');
            $cashiers[$id] ??= [
                'label' => $id === '' ? null : ($names[$id] ?? $id),
                'sales_count' => 0,
                'revenue' => 0,
            ];
            $cashiers[$id]['sales_count']++;
            $cashiers[$id]['revenue'] += (int) $sale->total;
        }

        return [
            'by_product' => $this->ranked($products),
            'by_category' => $this->ranked($categories),
            'by_cashier' => $this->ranked($cashiers),
        ];
    }

    /**
     * @param  array<string, array<string, mixed>>  $rows
     * @return list<array<string, mixed>>
     */
    private function ranked(array $rows): array
    {
        $list = array_values($rows);
        usort($list, fn (array $a, array $b) => ($b['revenue'] ?? 0) <=> ($a['revenue'] ?? 0));

        return array_slice($list, 0, 20);
    }

    /** @return list<array<string, mixed>> */
    private function stockMovements(?string $warehouseId, ?Carbon $from, ?Carbon $to, bool $lossesOnly): array
    {
        if (! Schema::hasTable('inventory_movements')) {
            return [];
        }

        $query = InventoryMovement::query()
            ->with(['product:id,sku,name,cost_price', 'warehouse:id,name'])
            ->orderByDesc('occurred_at');

        if ($warehouseId) {
            $query->where('warehouse_id', $warehouseId);
        }
        if ($from) {
            $query->where('occurred_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $query->where('occurred_at', '<=', $to->copy()->endOfDay());
        }
        if ($lossesOnly) {
            $query->whereIn('movement_type', ['LOSS', 'DAMAGE', 'EXPIRED', 'ADJUSTMENT_OUT']);
        }

        return $query->limit(40)->get()->map(function (InventoryMovement $movement) {
            $qty = (int) $movement->quantity;
            $unit = (int) ($movement->unit_cost ?: $movement->product?->cost_price ?: 0);

            return [
                'occurred_at' => $movement->occurred_at?->toIso8601String(),
                'type' => $movement->movement_type?->value ?? (string) $movement->movement_type,
                'sku' => $movement->product?->sku,
                'name' => $movement->product?->name,
                'warehouse' => $movement->warehouse?->name,
                'quantity' => $qty,
                'amount' => abs($qty) * $unit,
            ];
        })->all();
    }

    private function lossValue(?string $warehouseId, ?Carbon $from, ?Carbon $to): int
    {
        if (! Schema::hasTable('inventory_movements')) {
            return 0;
        }

        $query = InventoryMovement::query()
            ->with('product:id,cost_price')
            ->whereIn('movement_type', ['LOSS', 'DAMAGE', 'EXPIRED', 'ADJUSTMENT_OUT']);
        if ($warehouseId) {
            $query->where('warehouse_id', $warehouseId);
        }
        if ($from) {
            $query->where('occurred_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $query->where('occurred_at', '<=', $to->copy()->endOfDay());
        }

        return (int) $query->get(['quantity', 'unit_cost', 'product_id'])->sum(function (InventoryMovement $movement) {
            $unit = (int) ($movement->unit_cost ?: $movement->product?->cost_price ?: 0);

            return abs((int) $movement->quantity) * $unit;
        });
    }

    /** @return list<array<string, mixed>> */
    private function expiringStock(?string $warehouseId): array
    {
        if (! Schema::hasTable('stock_balances') || ! Schema::hasTable('batches')) {
            return [];
        }

        return StockBalance::query()
            ->with(['product:id,sku,name', 'warehouse:id,name', 'batch:id,batch_number,expires_at'])
            ->where('quantity_on_hand', '>', 0)
            ->when($warehouseId, fn ($query) => $query->where('warehouse_id', $warehouseId))
            ->whereNotNull('batch_id')
            ->get()
            ->filter(fn (StockBalance $balance) => $balance->batch?->expires_at !== null)
            ->sortBy(fn (StockBalance $balance) => $balance->batch->expires_at->timestamp)
            ->take(40)
            ->values()
            ->map(fn (StockBalance $balance) => [
                'sku' => $balance->product?->sku,
                'name' => $balance->product?->name,
                'warehouse' => $balance->warehouse?->name,
                'batch' => $balance->batch?->batch_number,
                'expires_at' => $balance->batch?->expires_at?->toDateString(),
                'quantity_on_hand' => (int) $balance->quantity_on_hand,
                'expired' => $balance->batch?->expires_at?->isPast() ?? false,
            ])
            ->all();
    }

    /** @return array{revenue: int, cogs: int, expenses: int, credit: int, debts: int} */
    private function operationalFinance(?Carbon $from, ?Carbon $to): array
    {
        $sales = Sale::query()->where('status', 'completed');
        if ($from) {
            $sales->where('completed_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $sales->where('completed_at', '<=', $to->copy()->endOfDay());
        }
        $rows = Schema::hasTable('sales') ? $sales->get(['id', 'total', 'paid_amount']) : collect();

        $cogs = 0;
        if ($rows->isNotEmpty() && Schema::hasTable('sale_items')) {
            $items = SaleItem::query()
                ->whereIn('sale_id', $rows->pluck('id'))
                ->with('product:id,cost_price')
                ->get(['id', 'product_id', 'quantity']);
            $cogs = (int) $items->sum(fn (SaleItem $item) => (int) $item->quantity * (int) ($item->product?->cost_price ?? 0));
        }

        $expenses = 0;
        $unpaid = 0;
        if (Schema::hasTable('branch_expenses')) {
            $expenseQuery = Expense::query();
            if ($from) {
                $expenseQuery->whereDate('occurred_on', '>=', $from->toDateString());
            }
            if ($to) {
                $expenseQuery->whereDate('occurred_on', '<=', $to->toDateString());
            }
            $expenseRows = $expenseQuery->get(['amount', 'cash_register_session_id']);
            $expenses = (int) $expenseRows->sum('amount');
            $unpaid = (int) $expenseRows
                ->filter(fn (Expense $expense) => $expense->cash_register_session_id === null)
                ->sum('amount');
        }

        $supplierDebt = 0;
        try {
            $supplierDebt = (int) ($this->payables->summary((string) (auth()->user()?->tenant_id ?? ''))['total_debt'] ?? 0);
        } catch (\Throwable) {
            $supplierDebt = 0;
        }

        return [
            'revenue' => (int) $rows->sum('total'),
            'cogs' => $cogs,
            'expenses' => $expenses,
            'credit' => (int) $rows->sum(fn (Sale $sale) => max(0, (int) $sale->total - (int) $sale->paid_amount)),
            'debts' => $unpaid + $supplierDebt,
        ];
    }
}
