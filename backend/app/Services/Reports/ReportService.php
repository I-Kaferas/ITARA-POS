<?php

namespace App\Services\Reports;

use App\Enums\SalePaymentMethod;
use App\Enums\SalePaymentStatus;
use App\Models\AccountingEntry;
use App\Models\CashierShift;
use App\Models\Expense;
use App\Models\GoodsReceipt;
use App\Models\InventoryAlert;
use App\Models\InventoryMovement;
use App\Models\PurchaseOrder;
use App\Models\PurchaseOrderItem;
use App\Models\Sale;
use App\Models\SaleInvoice;
use App\Models\SaleItem;
use App\Models\SalePayment;
use App\Models\SaleReturn;
use App\Models\CompanyPaymentMethod;
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

        $returns = (clone $returnsQuery)->get(['id', 'reason', 'total']);
        $salesCount = $sales->count();
        $revenue = (int) $sales->sum('total');
        $paidAmount = (int) $sales->sum('paid_amount');
        $outstanding = (int) $sales->sum(fn (Sale $s) => max(0, $s->total - $s->paid_amount));

        return [
            'sales_count' => $salesCount,
            'revenue' => $revenue,
            'subtotal' => (int) $sales->sum('subtotal'),
            'tax_total' => (int) $sales->sum('tax_total'),
            'discount_total' => (int) $sales->sum('discount_total'),
            'paid_amount' => $paidAmount,
            'outstanding_amount' => $outstanding,
            'average_order_value' => $salesCount > 0 ? (int) round($revenue / $salesCount) : 0,
            'quote_conversion' => [
                'converted' => 0,
                'total' => 0,
                'rate' => 0,
            ],
            'returns_count' => $returns->count(),
            'returns_total' => (int) $returns->sum('total'),
            'by_day' => $byDay,
            'by_week' => $breakdowns ? $this->groupSales($sales, 'week') : [],
            'by_month' => $breakdowns ? $this->groupSales($sales, 'month') : [],
            'by_year' => $breakdowns ? $this->groupSales($sales, 'year') : [],
            'by_weekday' => $breakdowns ? $this->salesByWeekday($sales) : [],
            'aov_by_day' => $breakdowns ? $this->aovByDay($byDay) : [],
            'monthly_revenue' => $breakdowns ? $this->monthlyRevenueBreakdown($sales) : [],
            'invoice_status' => $breakdowns ? $this->invoiceStatusDistribution($storeId, $from, $to) : [],
            'order_status' => $breakdowns ? $this->orderStatusDistribution($storeId, $from, $to) : [],
            'delivery' => [],
            'returns_by_type' => $breakdowns ? $this->returnsByType($returns) : [],
            ...($breakdowns ? $this->salesDimensions($sales) : [
                'by_product' => [],
                'by_category' => [],
                'by_cashier' => [],
                'by_customer' => [],
                'by_location' => [],
                'customer_summary' => [
                    'customers' => 0,
                    'revenue' => 0,
                    'unpaid' => 0,
                    'avg_revenue' => 0,
                ],
            ]),
        ];
    }

    /** @return array<string, mixed> */
    public function purchasesSummary(?Carbon $from = null, ?Carbon $to = null): array
    {
        if (! Schema::hasTable('purchase_orders')) {
            return $this->emptyPurchasesSummary();
        }

        $query = PurchaseOrder::query()->with(['supplier:id,name,code,address']);

        if ($from) {
            $query->where('created_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $query->where('created_at', '<=', $to->copy()->endOfDay());
        }

        $orders = (clone $query)->get();
        $totalSpend = (int) $orders->sum('total');
        $ordersCount = $orders->count();

        $monthsSpan = 12;
        if ($from && $to) {
            $monthsSpan = max(1, ((int) $from->diffInMonths($to)) + 1);
        }

        $bySupplier = $this->purchaseBySupplier($orders, $totalSpend);
        $receiptBundle = $this->purchaseReceiptBundle($from, $to);

        return [
            'total_spend' => $totalSpend,
            'orders_count' => $ordersCount,
            'suppliers_count' => $orders->pluck('supplier_id')->filter()->unique()->count(),
            'months_span' => $monthsSpan,
            'average_order_value' => $ordersCount > 0 ? (int) round($totalSpend / $ordersCount) : 0,
            'monthly_spend' => $this->purchaseMonthlySpend($orders, $from, $to),
            'order_status' => $this->purchaseOrderStatusDistribution($orders),
            'top_categories' => $this->purchaseTopCategories($orders),
            'by_supplier' => $bySupplier,
            'supplier_concentration' => $this->purchaseSupplierConcentration($bySupplier, $totalSpend),
            'receipt_summary' => $receiptBundle['summary'],
            'receipts' => $receiptBundle['receipts'],
            'receipts_count' => count($receiptBundle['receipts']),
        ];
    }

    /** @return array<string, mixed> */
    public function forecastsSummary(?string $storeId = null): array
    {
        $confidenceLevel = 80;
        $bandLowFactor = 0.8;
        $bandHighFactor = 1.2;
        $historyMonths = 12;
        $forecastMonths = 6;

        $end = now()->endOfMonth();
        $start = now()->copy()->subMonths($historyMonths - 1)->startOfMonth();

        $query = Sale::query()->where('status', 'completed');
        if ($storeId) {
            $query->where('store_id', $storeId);
        }
        $query->where('completed_at', '>=', $start)
            ->where('completed_at', '<=', $end);

        $sales = Schema::hasTable('sales') ? $query->get(['id', 'total', 'completed_at']) : collect();

        $byMonth = $sales
            ->filter(fn (Sale $sale) => $sale->completed_at !== null)
            ->groupBy(fn (Sale $sale) => $sale->completed_at->format('Y-m'));

        $history = [];
        $cursor = $start->copy()->startOfMonth();
        while ($cursor->lte($end->copy()->startOfMonth())) {
            $label = $cursor->format('Y-m');
            $bucket = $byMonth->get($label, collect());
            $history[] = [
                'label' => $label,
                'actual' => (int) $bucket->sum('total'),
                'forecast' => null,
                'lower' => null,
                'upper' => null,
                'kind' => 'actual',
            ];
            $cursor->addMonth();
        }

        $actualValues = array_map(fn (array $row) => (int) $row['actual'], $history);
        $growthRates = [];
        for ($i = 1; $i < count($actualValues); $i++) {
            $prev = $actualValues[$i - 1];
            $curr = $actualValues[$i];
            if ($prev > 0) {
                $growthRates[] = (($curr - $prev) / $prev) * 100;
            } elseif ($curr > 0) {
                $growthRates[] = 100.0;
            } else {
                $growthRates[] = 0.0;
            }
        }

        $avgGrowth = $growthRates !== []
            ? array_sum($growthRates) / count($growthRates)
            : 0.0;

        $recent = array_slice($actualValues, -3);
        $baseline = $recent !== []
            ? (int) round(array_sum($recent) / count($recent))
            : 0;
        $lastActual = $actualValues !== [] ? (int) end($actualValues) : 0;
        $growthFactor = 1 + ($avgGrowth / 100);
        if ($growthFactor < 0.5) {
            $growthFactor = 0.5;
        }
        if ($growthFactor > 2) {
            $growthFactor = 2;
        }

        $nextMonth = $lastActual > 0
            ? (int) max(0, round($lastActual * $growthFactor))
            : $baseline;

        $forecastRows = [];
        $projected = $nextMonth;
        $forecastCursor = now()->copy()->addMonth()->startOfMonth();
        for ($i = 0; $i < $forecastMonths; $i++) {
            if ($i > 0) {
                $projected = (int) max(0, round($projected * $growthFactor));
            }
            $lower = (int) round($projected * $bandLowFactor);
            $upper = (int) round($projected * $bandHighFactor);
            $forecastRows[] = [
                'label' => $forecastCursor->format('Y-m'),
                'actual' => null,
                'forecast' => $projected,
                'lower' => $lower,
                'upper' => $upper,
                'range' => $upper - $lower,
                'kind' => 'forecast',
            ];
            $forecastCursor->addMonth();
        }

        $sixMonthTotal = (int) array_sum(array_map(fn (array $row) => (int) $row['forecast'], $forecastRows));

        $series = array_merge(
            array_map(static function (array $row) {
                return [
                    'label' => $row['label'],
                    'actual' => $row['actual'],
                    'forecast' => null,
                    'lower' => null,
                    'upper' => null,
                    'kind' => 'actual',
                ];
            }, $history),
            array_map(static function (array $row) {
                return [
                    'label' => $row['label'],
                    'actual' => null,
                    'forecast' => $row['forecast'],
                    'lower' => $row['lower'],
                    'upper' => $row['upper'],
                    'kind' => 'forecast',
                ];
            }, $forecastRows),
        );

        // Bridge point: last historical month also carries forecast = actual for continuity.
        if ($series !== [] && $forecastRows !== []) {
            $lastHistoryIndex = count($history) - 1;
            if ($lastHistoryIndex >= 0) {
                $series[$lastHistoryIndex]['forecast'] = $history[$lastHistoryIndex]['actual'];
                $series[$lastHistoryIndex]['lower'] = (int) round(((int) $history[$lastHistoryIndex]['actual']) * $bandLowFactor);
                $series[$lastHistoryIndex]['upper'] = (int) round(((int) $history[$lastHistoryIndex]['actual']) * $bandHighFactor);
            }
        }

        $monthlyGrowth = [];
        for ($i = 1; $i < count($history); $i++) {
            $monthlyGrowth[] = [
                'label' => $history[$i]['label'],
                'rate' => round($growthRates[$i - 1], 1),
                'revenue' => $history[$i]['actual'],
            ];
        }

        $growingProducts = $this->forecastGrowingProducts($sales);
        $trajectory = abs($avgGrowth) < 2 ? 'stable' : ($avgGrowth > 0 ? 'growth' : 'decline');
        $cashflow = $sixMonthTotal <= 0 ? 'hard' : ($avgGrowth >= 5 ? 'strong' : 'moderate');

        return [
            'next_month_forecast' => $nextMonth,
            'six_month_forecast' => $sixMonthTotal,
            'avg_monthly_growth' => round($avgGrowth, 1),
            'confidence_level' => $confidenceLevel,
            'confidence_band_pct' => 20,
            'series' => $series,
            'monthly_growth' => $monthlyGrowth,
            'growing_products' => $growingProducts,
            'has_growth_data' => count($history) >= 2 && $sales->isNotEmpty(),
            'forecast_table' => $forecastRows,
            'insights' => [
                'trajectory' => $trajectory,
                'demand_next_month' => $nextMonth,
                'cashflow' => $cashflow,
                'six_month_forecast' => $sixMonthTotal,
            ],
        ];
    }

    /** @return array<string, mixed> */
    public function inventorySummary(?string $warehouseId, ?Carbon $from = null, ?Carbon $to = null): array
    {
        $query = StockBalance::query()->with([
            'product:id,sku,name,cost_price,base_price,low_stock_threshold,category_id',
            'product.category:id,name',
            'warehouse:id,name,code',
        ]);

        if ($warehouseId) {
            $query->where('warehouse_id', $warehouseId);
        }

        $balances = $query->get();
        $defaultThreshold = (int) config('inventory.default_low_stock_threshold', 10);
        $openAlerts = InventoryAlert::query()
            ->where('status', '!=', 'resolved')
            ->when($warehouseId, fn ($q) => $q->where('warehouse_id', $warehouseId))
            ->count();

        $classified = $balances->map(function (StockBalance $balance) use ($defaultThreshold) {
            $qty = (int) $balance->quantity_on_hand;
            $threshold = (int) ($balance->product?->low_stock_threshold ?? $defaultThreshold);
            if ($threshold <= 0) {
                $threshold = $defaultThreshold;
            }
            $unitCost = (int) ($balance->product?->cost_price ?? 0);
            $value = $unitCost * $qty;
            $status = $this->stockHealthStatus($qty, $threshold);

            return [
                'product_id' => $balance->product_id,
                'sku' => $balance->product?->sku,
                'name' => $balance->product?->name,
                'category' => $balance->product?->category?->name,
                'warehouse' => $balance->warehouse?->name,
                'warehouse_id' => $balance->warehouse_id,
                'quantity_on_hand' => $qty,
                'quantity_available' => (int) $balance->quantity_available,
                'reorder_point' => $threshold,
                'unit_cost' => $unitCost,
                'value' => $value,
                'status' => $status,
            ];
        });

        $healthyCount = $classified->where('status', 'healthy')->count();
        $lowStockCount = $classified->where('status', 'low')->count();
        $outOfStockCount = $classified->where('status', 'out')->count();
        $overstockCount = $classified->where('status', 'over')->count();
        $totalValue = (int) $classified->sum('value');

        $lowStockRows = $classified
            ->whereIn('status', ['low', 'out'])
            ->sortBy('quantity_on_hand')
            ->values();

        $stockLevels = $classified
            ->sortByDesc('value')
            ->take(20)
            ->values()
            ->all();

        $byCategory = $classified
            ->groupBy(fn (array $row) => $row['category'] ?: '—')
            ->map(fn (Collection $group, string $label) => [
                'label' => $label,
                'quantity' => (int) $group->sum('quantity_on_hand'),
                'value' => (int) $group->sum('value'),
            ])
            ->sortByDesc('value')
            ->values()
            ->take(12)
            ->all();

        $byWarehouse = $classified
            ->groupBy(fn (array $row) => $row['warehouse'] ?: '—')
            ->map(fn (Collection $group, string $label) => [
                'label' => $label,
                'quantity' => (int) $group->sum('quantity_on_hand'),
                'value' => (int) $group->sum('value'),
            ])
            ->sortByDesc('value')
            ->values()
            ->all();

        $aging = $this->agingBuckets($warehouseId);
        $turnover = $this->turnoverAnalysis($classified, $warehouseId, $from, $to);

        return [
            'skus_in_stock' => $classified->where('quantity_on_hand', '>', 0)->count(),
            'total_articles' => $classified->count(),
            'total_units' => (int) $classified->sum('quantity_on_hand'),
            'total_available' => (int) $classified->sum('quantity_available'),
            'estimated_value' => $totalValue,
            'open_alerts' => $openAlerts,
            'healthy_count' => $healthyCount,
            'low_stock_count' => $lowStockCount,
            'out_of_stock_count' => $outOfStockCount,
            'overstock_count' => $overstockCount,
            'stock_health' => [
                ['label' => 'healthy', 'count' => $healthyCount],
                ['label' => 'low', 'count' => $lowStockCount],
                ['label' => 'out', 'count' => $outOfStockCount],
                ['label' => 'over', 'count' => $overstockCount],
            ],
            'by_category' => $byCategory,
            'by_warehouse' => $byWarehouse,
            'stock_levels' => $stockLevels,
            'top_items' => $classified
                ->sortByDesc('quantity_on_hand')
                ->take(20)
                ->values()
                ->map(fn (array $row) => [
                    'product_id' => $row['product_id'],
                    'sku' => $row['sku'],
                    'name' => $row['name'],
                    'warehouse' => $row['warehouse'],
                    'quantity_on_hand' => $row['quantity_on_hand'],
                    'quantity_available' => $row['quantity_available'],
                ])
                ->all(),
            'low_stock' => $lowStockRows
                ->take(40)
                ->map(fn (array $row) => [
                    'product_id' => $row['product_id'],
                    'sku' => $row['sku'],
                    'name' => $row['name'],
                    'warehouse' => $row['warehouse'],
                    'quantity_on_hand' => $row['quantity_on_hand'],
                    'threshold' => $row['reorder_point'],
                ])
                ->all(),
            'movements' => $this->stockMovements($warehouseId, $from, $to, lossesOnly: false),
            'losses' => $this->stockMovements($warehouseId, $from, $to, lossesOnly: true),
            'losses_value' => $this->lossValue($warehouseId, $from, $to),
            'expiration' => $this->expiringStock($warehouseId),
            'aging' => $aging,
            'turnover' => $turnover,
        ];
    }

    private function stockHealthStatus(int $qty, int $threshold): string
    {
        if ($qty <= 0) {
            return 'out';
        }
        if ($qty <= $threshold) {
            return 'low';
        }
        if ($qty > max($threshold * 3, $threshold + 50)) {
            return 'over';
        }

        return 'healthy';
    }

    /**
     * @return list<array{label: string, count: int, quantity: int}>
     */
    private function agingBuckets(?string $warehouseId): array
    {
        $rows = $this->expiringStock($warehouseId);
        $buckets = [
            'expired' => ['label' => 'expired', 'count' => 0, 'quantity' => 0],
            '0_30' => ['label' => '0_30', 'count' => 0, 'quantity' => 0],
            '31_60' => ['label' => '31_60', 'count' => 0, 'quantity' => 0],
            '61_90' => ['label' => '61_90', 'count' => 0, 'quantity' => 0],
            '90_plus' => ['label' => '90_plus', 'count' => 0, 'quantity' => 0],
        ];

        foreach ($rows as $row) {
            $qty = (int) ($row['quantity_on_hand'] ?? 0);
            $daysLeft = $row['days_left'] ?? null;
            if ($daysLeft === null) {
                continue;
            }
            $key = match (true) {
                ($row['expired'] ?? false) || $daysLeft < 0 => 'expired',
                $daysLeft <= 30 => '0_30',
                $daysLeft <= 60 => '31_60',
                $daysLeft <= 90 => '61_90',
                default => '90_plus',
            };
            $buckets[$key]['count']++;
            $buckets[$key]['quantity'] += $qty;
        }

        return array_values($buckets);
    }

    /**
     * @param  Collection<int, array<string, mixed>>  $classified
     * @return list<array<string, mixed>>
     */
    private function turnoverAnalysis(Collection $classified, ?string $warehouseId, ?Carbon $from, ?Carbon $to): array
    {
        if (! Schema::hasTable('inventory_movements') || $classified->isEmpty()) {
            return [];
        }

        $from = $from ?? now()->subDays(90)->startOfDay();
        $to = $to ?? now()->endOfDay();
        $days = max(1, $from->diffInDays($to) ?: 90);

        $sold = InventoryMovement::query()
            ->select('product_id', DB::raw('SUM(ABS(quantity)) as sold_qty'))
            ->where('movement_type', 'SALE')
            ->where('occurred_at', '>=', $from)
            ->where('occurred_at', '<=', $to)
            ->when($warehouseId, fn ($q) => $q->where('warehouse_id', $warehouseId))
            ->groupBy('product_id')
            ->pluck('sold_qty', 'product_id');

        return $classified
            ->groupBy('product_id')
            ->map(function (Collection $group, string $productId) use ($sold, $days) {
                $first = $group->first();
                $onHand = (int) $group->sum('quantity_on_hand');
                $soldQty = (int) ($sold[$productId] ?? 0);
                $avgStock = max($onHand, 1);
                $turnover = round($soldQty / $avgStock, 2);
                $daysOfSupply = $soldQty > 0
                    ? (int) round(($onHand / ($soldQty / $days)))
                    : ($onHand > 0 ? null : 0);

                return [
                    'product_id' => $productId,
                    'sku' => $first['sku'] ?? null,
                    'name' => $first['name'] ?? null,
                    'category' => $first['category'] ?? null,
                    'quantity_on_hand' => $onHand,
                    'sold_qty' => $soldQty,
                    'turnover_rate' => $turnover,
                    'days_of_supply' => $daysOfSupply,
                    'value' => (int) $group->sum('value'),
                ];
            })
            ->sortByDesc('turnover_rate')
            ->take(40)
            ->values()
            ->all();
    }

    /**
     * Rapport de recette — produits vendus, coûts, marges et ventilation.
     *
     * @return array<string, mixed>
     */
    public function revenueSummary(?string $storeId, ?Carbon $from, ?Carbon $to): array
    {
        $query = Sale::query()->where('status', 'completed');

        if ($storeId) {
            $query->where('store_id', $storeId);
        }

        if ($from) {
            $query->where('completed_at', '>=', $this->boundStart($from));
        }

        if ($to) {
            $query->where('completed_at', '<=', $this->boundEnd($to));
        }

        $sales = (clone $query)->get(['id', 'total', 'subtotal', 'tax_total', 'discount_total', 'completed_at']);
        $salesCount = $sales->count();
        $revenue = (int) $sales->sum('total');
        $subtotal = (int) $sales->sum('subtotal');
        $taxTotal = (int) $sales->sum('tax_total');
        $discountTotal = (int) $sales->sum('discount_total');

        $byDay = (clone $query)
            ->select(
                DB::raw('DATE(completed_at) as day'),
                DB::raw('COUNT(*) as sales_count'),
                DB::raw('SUM(total) as revenue'),
            )
            ->groupBy(DB::raw('DATE(completed_at)'))
            ->orderBy('day')
            ->get()
            ->map(fn ($row) => [
                'day' => (string) $row->day,
                'sales_count' => (int) $row->sales_count,
                'revenue' => (int) $row->revenue,
            ])
            ->values()
            ->all();

        $products = [];
        $categories = [];
        $houseOffer = 0;
        $salesProductCount = 0;
        $accompanimentCount = 0;
        $cogs = 0;

        if (Schema::hasTable('sale_items') && $sales->isNotEmpty()) {
            $items = SaleItem::query()
                ->whereIn('sale_id', $sales->pluck('id'))
                ->with(['product:id,name,sku,cost_price,category_id', 'product.category:id,name'])
                ->get([
                    'id', 'sale_id', 'product_id', 'product_name', 'product_sku',
                    'quantity', 'unit_price', 'catalog_price', 'line_subtotal', 'line_tax', 'line_total',
                    'is_accompaniment',
                ]);

            foreach ($items as $item) {
                $qty = (int) $item->quantity;
                $lineTotal = (int) $item->line_total;
                $lineTax = (int) $item->line_tax;
                $unitPrice = (int) $item->unit_price;
                $catalogPrice = (int) ($item->catalog_price ?? 0);
                $costPrice = $item->product?->cost_price !== null ? (int) $item->product->cost_price : null;
                $isAccompaniment = (bool) $item->is_accompaniment;
                $category = $item->product?->category?->name;

                if ($isAccompaniment || $lineTotal === 0) {
                    $houseOffer += ($catalogPrice > 0 ? $catalogPrice : $unitPrice) * $qty;
                }

                $lineCost = $costPrice !== null ? $costPrice * $qty : 0;
                $cogs += $lineCost;
                $grossProfit = $lineTotal - $lineCost;

                $productKey = ($item->product_id ?: ($item->product_name ?: 'article'))
                    .'|'.($isAccompaniment ? 'a' : 's');

                $products[$productKey] ??= [
                    'label' => $item->product?->name ?? $item->product_name ?? $productKey,
                    'sku' => $item->product?->sku ?? $item->product_sku,
                    'category' => $category,
                    'quantity' => 0,
                    'cost_price' => $costPrice,
                    'unit_price' => 0,
                    'revenue' => 0,
                    'cogs' => 0,
                    'gross_profit' => 0,
                    'tax_total' => 0,
                    'invoices' => 0,
                    'is_accompaniment' => $isAccompaniment,
                    '_sale_ids' => [],
                    '_price_sum' => 0,
                    '_price_qty' => 0,
                    '_has_cost' => false,
                    '_cost_sum' => 0,
                    '_cost_qty' => 0,
                ];

                $products[$productKey]['quantity'] += $qty;
                $products[$productKey]['revenue'] += $lineTotal;
                $products[$productKey]['cogs'] += $lineCost;
                $products[$productKey]['gross_profit'] += $grossProfit;
                $products[$productKey]['tax_total'] += $lineTax;
                $products[$productKey]['_sale_ids'][(string) $item->sale_id] = true;
                $products[$productKey]['_price_sum'] += $unitPrice * $qty;
                $products[$productKey]['_price_qty'] += $qty;

                if ($costPrice !== null) {
                    $products[$productKey]['_has_cost'] = true;
                    $products[$productKey]['_cost_sum'] += $costPrice * $qty;
                    $products[$productKey]['_cost_qty'] += $qty;
                }

                $categoryKey = $category ?: '';
                $categories[$categoryKey] ??= [
                    'label' => $category,
                    'quantity' => 0,
                    'revenue' => 0,
                    'share' => 0,
                ];
                $categories[$categoryKey]['quantity'] += $qty;
                $categories[$categoryKey]['revenue'] += $lineTotal;
            }

            foreach ($products as &$product) {
                $product['invoices'] = count($product['_sale_ids']);
                $priceQty = (int) $product['_price_qty'];
                $product['unit_price'] = $priceQty > 0
                    ? (int) round(((int) $product['_price_sum']) / $priceQty)
                    : 0;

                if ($product['_has_cost'] && (int) $product['_cost_qty'] > 0) {
                    $product['cost_price'] = (int) round(((int) $product['_cost_sum']) / (int) $product['_cost_qty']);
                } else {
                    $product['cost_price'] = null;
                }

                $rev = (int) $product['revenue'];
                $gp = (int) $product['gross_profit'];
                $product['margin_pct'] = $rev > 0
                    ? round(($gp / $rev) * 1000) / 10
                    : (($product['cost_price'] ?? 0) === 0 ? 100.0 : 0.0);

                unset(
                    $product['_sale_ids'],
                    $product['_price_sum'],
                    $product['_price_qty'],
                    $product['_has_cost'],
                    $product['_cost_sum'],
                    $product['_cost_qty'],
                );

                if ($product['is_accompaniment']) {
                    $accompanimentCount++;
                } else {
                    $salesProductCount++;
                }
            }
            unset($product);

            $categoryRevenueTotal = array_sum(array_map(fn (array $row) => (int) $row['revenue'], $categories));
            foreach ($categories as &$categoryRow) {
                $rev = (int) $categoryRow['revenue'];
                $categoryRow['share'] = $categoryRevenueTotal > 0
                    ? round(($rev / $categoryRevenueTotal) * 1000) / 10
                    : 0;
            }
            unset($categoryRow);
        }

        $productList = array_values($products);
        usort($productList, fn (array $a, array $b) => ((int) $b['quantity']) <=> ((int) $a['quantity']));

        $categoryList = array_values($categories);
        usort($categoryList, fn (array $a, array $b) => ((int) $b['revenue']) <=> ((int) $a['revenue']));

        $grossProfit = $revenue - $cogs;
        $marginPct = $revenue > 0 ? round(($grossProfit / $revenue) * 1000) / 10 : 0.0;

        return [
            'from' => $from?->toDateTimeString(),
            'to' => $to?->toDateTimeString(),
            'store_id' => $storeId,
            'total' => $revenue,
            'subtotal' => $subtotal,
            'gross_profit' => $grossProfit,
            'margin_pct' => $marginPct,
            'tax_total' => $taxTotal,
            'discount_total' => $discountTotal,
            'invoices_count' => $salesCount,
            'house_offer' => $houseOffer,
            'products_count' => count($productList),
            'sales_products_count' => $salesProductCount,
            'accompaniments_count' => $accompanimentCount,
            'by_day' => $byDay,
            'by_category' => $categoryList,
            'by_product' => $productList,
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

    /** @return array<string, mixed> */
    public function condensedSummary(?string $storeId, ?Carbon $from, ?Carbon $to): array
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

        $sales = (clone $query)->get(['id', 'total', 'paid_amount', 'tax_total', 'discount_total', 'payment_status']);

        $totalBilled = (int) $sales->sum('total');
        $totalCollected = (int) $sales->sum('paid_amount');
        $totalCredit = (int) $sales->sum(fn (Sale $sale) => max(0, (int) $sale->total - (int) $sale->paid_amount));
        $taxCollected = (int) $sales->sum('tax_total');
        $discountTotal = (int) $sales->sum('discount_total');

        return [
            'total_billed' => $totalBilled,
            'invoice_count' => $sales->count(),
            'total_collected' => $totalCollected,
            'total_credit' => $totalCredit,
            'tax_collected' => $taxCollected,
            'discount_total' => $discountTotal,
            'by_payment_method' => $this->condensedByPaymentMethod($sales),
            'by_payment_status' => $this->condensedByPaymentStatus($sales, $totalBilled),
        ];
    }

    /** @return array<string, mixed> */
    public function dailyCalendar(?string $storeId, Carbon $month): array
    {
        $from = $month->copy()->startOfMonth()->startOfDay();
        $to = $month->copy()->endOfMonth()->endOfDay();

        $sales = $this->completedSalesQuery($storeId, $from, $to)
            ->get(['id', 'total', 'paid_amount', 'tax_total', 'discount_total', 'completed_at']);

        $houseBySale = $this->houseOfferBySaleIds($sales->pluck('id')->all());
        $cogsBySale = $this->cogsBySaleIds($sales->pluck('id')->all());
        $cashBySale = $this->cashCollectedBySaleIds($sales->pluck('id')->map(fn ($id) => (string) $id)->all());

        $byDay = [];
        foreach ($sales as $sale) {
            $day = $sale->completed_at?->toDateString();
            if (! $day) {
                continue;
            }

            $byDay[$day] ??= [
                'day' => $day,
                'revenue' => 0,
                'net_revenue' => 0,
                'collected' => 0,
                'credit' => 0,
                'tax_total' => 0,
                'discount_total' => 0,
                'house_offer' => 0,
                'cogs' => 0,
                'invoices_count' => 0,
            ];

            $total = (int) $sale->total;
            $paid = (int) $sale->paid_amount;
            $tax = (int) $sale->tax_total;
            $saleId = (string) $sale->id;

            $byDay[$day]['revenue'] += $total;
            $byDay[$day]['net_revenue'] += max(0, $total - $tax);
            $byDay[$day]['collected'] += (int) ($cashBySale[$saleId] ?? 0);
            $byDay[$day]['credit'] += max(0, $total - $paid);
            $byDay[$day]['tax_total'] += $tax;
            $byDay[$day]['discount_total'] += (int) $sale->discount_total;
            $byDay[$day]['house_offer'] += (int) ($houseBySale[$saleId] ?? 0);
            $byDay[$day]['cogs'] += (int) ($cogsBySale[$saleId] ?? 0);
            $byDay[$day]['invoices_count']++;
        }

        $days = [];
        $cursor = $from->copy();
        while ($cursor->lte($to)) {
            $key = $cursor->toDateString();
            $row = $byDay[$key] ?? [
                'day' => $key,
                'revenue' => 0,
                'net_revenue' => 0,
                'collected' => 0,
                'credit' => 0,
                'tax_total' => 0,
                'discount_total' => 0,
                'house_offer' => 0,
                'cogs' => 0,
                'invoices_count' => 0,
            ];
            $revenue = (int) $row['revenue'];
            $cogs = (int) $row['cogs'];
            $grossProfit = $revenue - $cogs;
            $days[] = [
                'day' => $key,
                'revenue' => $revenue,
                'net_revenue' => (int) $row['net_revenue'],
                'collected' => (int) $row['collected'],
                'credit' => (int) $row['credit'],
                'tax_total' => (int) $row['tax_total'],
                'discount_total' => (int) $row['discount_total'],
                'house_offer' => (int) $row['house_offer'],
                'gross_profit' => $grossProfit,
                'margin_pct' => $revenue > 0 ? round(($grossProfit / $revenue) * 1000) / 10 : 0.0,
                'invoices_count' => (int) $row['invoices_count'],
            ];
            $cursor->addDay();
        }

        $summaryRevenue = (int) array_sum(array_column($days, 'revenue'));
        $summaryCogs = (int) array_sum(array_map(fn (array $d) => (int) ($byDay[$d['day']]['cogs'] ?? 0), $days));
        $summaryGross = $summaryRevenue - $summaryCogs;

        return [
            'month' => $month->format('Y-m'),
            'summary' => [
                'revenue' => $summaryRevenue,
                'net_revenue' => (int) array_sum(array_column($days, 'net_revenue')),
                'collected' => (int) array_sum(array_column($days, 'collected')),
                'credit' => (int) array_sum(array_column($days, 'credit')),
                'tax_total' => (int) array_sum(array_column($days, 'tax_total')),
                'discount_total' => (int) array_sum(array_column($days, 'discount_total')),
                'house_offer' => (int) array_sum(array_column($days, 'house_offer')),
                'gross_profit' => $summaryGross,
                'margin_pct' => $summaryRevenue > 0 ? round(($summaryGross / $summaryRevenue) * 1000) / 10 : 0.0,
                'invoices_count' => (int) array_sum(array_column($days, 'invoices_count')),
            ],
            'days' => $days,
        ];
    }

    /** @return array<string, mixed> */
    public function dailyDetail(?string $storeId, Carbon $date): array
    {
        $from = $date->copy()->startOfDay();
        $to = $date->copy()->endOfDay();

        $sales = $this->completedSalesQuery($storeId, $from, $to)
            ->with([
                'customer:id,name',
                'invoices:id,sale_id,invoice_number,status',
            ])
            ->orderBy('completed_at')
            ->get([
                'id', 'reference', 'status', 'payment_status', 'customer_id',
                'total', 'paid_amount', 'tax_total', 'discount_total', 'subtotal', 'completed_at',
            ]);

        $saleIds = $sales->pluck('id')->map(fn ($id) => (string) $id)->all();
        $houseBySale = $this->houseOfferBySaleIds($saleIds);
        $cogsBySale = $this->cogsBySaleIds($saleIds);
        $cashBySale = $this->cashCollectedBySaleIds($saleIds);

        $revenue = (int) $sales->sum('total');
        $taxTotal = (int) $sales->sum('tax_total');
        $discountTotal = (int) $sales->sum('discount_total');
        $collected = (int) array_sum($cashBySale);
        $credit = (int) $sales->sum(fn (Sale $sale) => max(0, (int) $sale->total - (int) $sale->paid_amount));
        $houseOffer = (int) array_sum($houseBySale);
        $cogs = (int) array_sum($cogsBySale);
        $grossProfit = $revenue - $cogs;

        $byPaymentMethod = $this->condensedByPaymentMethod($sales);
        if ($houseOffer > 0) {
            $byPaymentMethod[] = [
                'payment_method' => 'house_offer',
                'label' => 'Offre maison',
                'amount' => $houseOffer,
                'count' => count(array_filter($houseBySale, fn (int $v) => $v > 0)),
                'share' => 0,
            ];
        }

        $invoices = $sales->map(function (Sale $sale) use ($houseBySale) {
            $saleId = (string) $sale->id;
            $invoice = $sale->relationLoaded('invoices') ? $sale->invoices->first() : null;
            $total = (int) $sale->total;
            $paid = (int) $sale->paid_amount;

            return [
                'id' => $saleId,
                'invoice_number' => $invoice?->invoice_number ?: $sale->reference,
                'reference' => $sale->reference,
                'customer_name' => $sale->customer?->name ?: 'POS Walk-in',
                'status' => $sale->status?->value ?? (string) $sale->status,
                'payment_status' => $sale->payment_status instanceof SalePaymentStatus
                    ? $sale->payment_status->value
                    : (string) ($sale->payment_status ?? 'unpaid'),
                'total' => $total,
                'paid_amount' => $paid,
                'outstanding_amount' => max(0, $total - $paid),
                'house_offer' => (int) ($houseBySale[$saleId] ?? 0),
                'completed_at' => $sale->completed_at?->toIso8601String(),
            ];
        })->values()->all();

        $products = $this->dailyProducts($saleIds);
        $payments = $this->dailyPayments($saleIds);

        return [
            'date' => $date->toDateString(),
            'summary' => [
                'revenue' => $revenue,
                'net_revenue' => max(0, $revenue - $taxTotal),
                'collected' => $collected,
                'credit' => $credit,
                'tax_total' => $taxTotal,
                'discount_total' => $discountTotal,
                'house_offer' => $houseOffer,
                'gross_profit' => $grossProfit,
                'margin_pct' => $revenue > 0 ? round(($grossProfit / $revenue) * 1000) / 10 : 0.0,
                'invoices_count' => $sales->count(),
            ],
            'by_payment_method' => $byPaymentMethod,
            'invoices' => $invoices,
            'products' => $products,
            'payments' => $payments,
        ];
    }

    /**
     * User / POS-session performance for a period.
     * POS invoice metrics are attributed to sale.processed_by (order author), not the cashier who collected.
     *
     * @return array<string, mixed>
     */
    public function userPerformanceSummary(?string $storeId, ?Carbon $from, ?Carbon $to): array
    {
        $fromBound = $from ? $this->boundStart($from) : now()->copy()->startOfMonth()->startOfDay();
        $toBound = $to ? $this->boundEnd($to) : now()->copy()->endOfDay();

        $users = User::query()
            ->with(['roles:id,name,slug'])
            ->orderBy('name')
            ->get(['id', 'name', 'email', 'is_active']);

        $salesQuery = Sale::query()->where('status', 'completed');
        if ($storeId) {
            $salesQuery->where('store_id', $storeId);
        }
        $sales = $salesQuery
            ->where('completed_at', '>=', $fromBound)
            ->where('completed_at', '<=', $toBound)
            ->get(['id', 'processed_by', 'total', 'paid_amount']);

        $openOrdersQuery = Sale::query()->whereIn('status', ['draft', 'pending']);
        if ($storeId) {
            $openOrdersQuery->where('store_id', $storeId);
        }
        $openOrders = $openOrdersQuery
            ->where('created_at', '>=', $fromBound)
            ->where('created_at', '<=', $toBound)
            ->get(['id', 'processed_by']);

        $purchaseByUser = [];
        if (Schema::hasTable('purchase_orders')) {
            $poQuery = PurchaseOrder::query()
                ->where('created_at', '>=', $fromBound)
                ->where('created_at', '<=', $toBound);
            if ($storeId && Schema::hasColumn('purchase_orders', 'store_id')) {
                $poQuery->where('store_id', $storeId);
            }
            $purchaseByUser = $poQuery
                ->get(['id', 'created_by'])
                ->groupBy(fn (PurchaseOrder $po) => (string) ($po->created_by ?? ''))
                ->map(fn (Collection $group) => $group->count())
                ->all();
        }

        $byUser = [];
        foreach ($users as $user) {
            $byUser[(string) $user->id] = [
                'user_id' => (string) $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'handle' => '@'.$user->email,
                'role' => $user->roles->first()?->slug ?? $user->roles->first()?->name ?? 'member',
                'role_name' => $user->roles->first()?->name,
                'is_active' => (bool) $user->is_active,
                'invoices_count' => 0,
                'invoiced_total' => 0,
                'collected_total' => 0,
                'credit_total' => 0,
                'orders_count' => 0,
                'purchase_orders_count' => (int) ($purchaseByUser[(string) $user->id] ?? 0),
            ];
        }

        foreach ($sales as $sale) {
            $uid = (string) ($sale->processed_by ?? '');
            if ($uid === '' || ! isset($byUser[$uid])) {
                continue;
            }
            $total = (int) $sale->total;
            $paid = (int) $sale->paid_amount;
            $byUser[$uid]['invoices_count']++;
            $byUser[$uid]['invoiced_total'] += $total;
            $byUser[$uid]['collected_total'] += $paid;
            $byUser[$uid]['credit_total'] += max(0, $total - $paid);
        }

        foreach ($openOrders as $order) {
            $uid = (string) ($order->processed_by ?? '');
            if ($uid === '' || ! isset($byUser[$uid])) {
                continue;
            }
            $byUser[$uid]['orders_count']++;
        }

        $rows = array_values($byUser);
        usort($rows, function (array $a, array $b) {
            $cmp = ($b['invoiced_total'] <=> $a['invoiced_total']);
            if ($cmp !== 0) {
                return $cmp;
            }

            return strcasecmp((string) $a['name'], (string) $b['name']);
        });

        $invoicedGrand = (int) array_sum(array_column($rows, 'invoiced_total'));
        foreach ($rows as &$row) {
            $row['share'] = $invoicedGrand > 0
                ? round(($row['invoiced_total'] / $invoicedGrand) * 1000) / 10
                : 0.0;
        }
        unset($row);

        $activeUsers = count(array_filter(
            $rows,
            fn (array $row) => $row['invoices_count'] > 0
                || $row['orders_count'] > 0
                || $row['purchase_orders_count'] > 0,
        ));

        $sessions = [];
        if (Schema::hasTable('cashier_shifts')) {
            $shiftQuery = CashierShift::query()
                ->with([
                    'cashier:id,name,email',
                    'cashRegister:id,name,code',
                ])
                ->where('opened_at', '>=', $fromBound)
                ->where('opened_at', '<=', $toBound)
                ->orderByDesc('opened_at');

            if ($storeId && Schema::hasColumn('cash_registers', 'store_id')) {
                $shiftQuery->whereHas('cashRegister', fn ($q) => $q->where('store_id', $storeId));
            }

            $shifts = $shiftQuery->limit(300)->get();
            $shiftIds = $shifts->pluck('id')->map(fn ($id) => (string) $id)->all();

            $salesByShift = [];
            if ($shiftIds !== []) {
                $saleRows = Sale::query()
                    ->whereIn('cashier_shift_id', $shiftIds)
                    ->where('status', 'completed')
                    ->get(['id', 'cashier_shift_id', 'total']);
                foreach ($saleRows as $sale) {
                    $sid = (string) $sale->cashier_shift_id;
                    $salesByShift[$sid] ??= ['orders_count' => 0, 'sales_total' => 0];
                    $salesByShift[$sid]['orders_count']++;
                    $salesByShift[$sid]['sales_total'] += (int) $sale->total;
                }
            }

            $now = now();
            $sessions = $shifts->map(function (CashierShift $shift) use ($salesByShift, $now) {
                $status = $shift->status?->value ?? (string) $shift->status;
                $shiftId = (string) $shift->id;
                $openedAt = $shift->opened_at;
                $closedAt = $shift->closed_at;
                $end = $closedAt ?? $now;
                $durationSeconds = $openedAt ? (int) max(0, $openedAt->diffInSeconds($end)) : 0;
                $stats = $salesByShift[$shiftId] ?? ['orders_count' => 0, 'sales_total' => 0];

                return [
                    'id' => $shiftId,
                    'session_number' => $this->cashierSessionNumber($shift),
                    'cashier_id' => (string) $shift->cashier_id,
                    'cashier_name' => $shift->cashier?->name,
                    'cashier_email' => $shift->cashier?->email,
                    'register_name' => $shift->cashRegister?->name,
                    'register_code' => $shift->cashRegister?->code,
                    'status' => $status,
                    'orders_count' => (int) $stats['orders_count'],
                    'sales_total' => (int) $stats['sales_total'],
                    'duration_total' => (int) $shift->sales_total,
                    'refunds_total' => (int) $shift->refunds_total,
                    'expected_cash' => (int) $shift->expected_cash,
                    'actual_cash' => $shift->actual_cash === null ? null : (int) $shift->actual_cash,
                    'variance' => $shift->variance === null ? null : (int) $shift->variance,
                    'duration_seconds' => $durationSeconds,
                    'opened_at' => $openedAt?->toIso8601String(),
                    'closed_at' => $closedAt?->toIso8601String(),
                ];
            })->values()->all();
        }

        return [
            'from' => $fromBound->toDateTimeString(),
            'to' => $toBound->toDateTimeString(),
            'summary' => [
                'active_users' => $activeUsers,
                'invoices_count' => (int) array_sum(array_column($rows, 'invoices_count')),
                'invoiced_total' => $invoicedGrand,
                'collected_total' => (int) array_sum(array_column($rows, 'collected_total')),
                'credit_total' => (int) array_sum(array_column($rows, 'credit_total')),
                'orders_count' => (int) array_sum(array_column($rows, 'orders_count')),
                'purchase_orders_count' => (int) array_sum(array_column($rows, 'purchase_orders_count')),
                'users_count' => count($rows),
                'sessions_count' => count($sessions),
            ],
            'users' => $rows,
            'sessions' => $sessions,
            'attribution_note' => 'processed_by',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function userPerformanceSessionDetail(string $shiftId): array
    {
        $shift = CashierShift::query()
            ->with([
                'cashier:id,name,email',
                'cashRegister:id,name,code',
            ])
            ->findOrFail($shiftId);

        $sales = Sale::query()
            ->where('cashier_shift_id', $shift->id)
            ->where('status', 'completed')
            ->with([
                'customer:id,name',
                'invoices:id,sale_id,invoice_number,status',
                'processedBy:id,name',
            ])
            ->orderByDesc('completed_at')
            ->get([
                'id', 'reference', 'status', 'payment_status', 'customer_id', 'processed_by',
                'total', 'paid_amount', 'tax_total', 'discount_total', 'completed_at',
            ]);

        $saleIds = $sales->pluck('id')->map(fn ($id) => (string) $id)->all();
        $houseBySale = $this->houseOfferBySaleIds($saleIds);
        $saleCreditMap = [];
        foreach ($sales as $sale) {
            $saleCreditMap[(string) $sale->id] = max(0, (int) $sale->total - (int) $sale->paid_amount) > 0;
        }
        $products = $this->sessionProducts($saleIds, $saleCreditMap);

        $openedAt = $shift->opened_at;
        $closedAt = $shift->closed_at;
        $end = $closedAt ?? now();
        $durationSeconds = $openedAt ? (int) max(0, $openedAt->diffInSeconds($end)) : 0;
        $status = $shift->status?->value ?? (string) $shift->status;
        $cashierName = $shift->cashier?->name;

        $invoiced = (int) $sales->sum('total');
        $collected = (int) $sales->sum('paid_amount');
        $credit = (int) $sales->sum(fn (Sale $sale) => max(0, (int) $sale->total - (int) $sale->paid_amount));

        $orders = $sales->map(function (Sale $sale) use ($houseBySale, $cashierName) {
            $saleId = (string) $sale->id;
            $invoice = $sale->relationLoaded('invoices') ? $sale->invoices->first() : null;
            $total = (int) $sale->total;
            $paid = (int) $sale->paid_amount;
            $houseOffer = (int) ($houseBySale[$saleId] ?? 0);
            $paymentStatus = $sale->payment_status instanceof SalePaymentStatus
                ? $sale->payment_status->value
                : (string) ($sale->payment_status ?? 'unpaid');
            if ($paymentStatus === 'on_credit') {
                $paymentStatus = 'credit';
            }
            $paymentLabel = ($houseOffer > 0 && $total === 0) ? 'house_offer' : $paymentStatus;

            return [
                'id' => $saleId,
                'order_number' => $invoice?->invoice_number ?: ($sale->reference ?: $saleId),
                'invoice_number' => $invoice?->invoice_number ?: $sale->reference,
                'reference' => $sale->reference,
                'customer_name' => $sale->customer?->name,
                'taken_by' => $sale->processedBy?->name,
                'paid_by' => $paid > 0 || $houseOffer > 0 ? $cashierName : null,
                'status' => $sale->status?->value ?? (string) $sale->status,
                'payment_status' => $paymentStatus,
                'payment_label' => $paymentLabel,
                'total' => $total,
                'paid_amount' => $paid,
                'outstanding_amount' => max(0, $total - $paid),
                'house_offer' => $houseOffer,
                'completed_at' => $sale->completed_at?->toIso8601String(),
            ];
        })->values()->all();

        return [
            'session' => [
                'id' => (string) $shift->id,
                'session_number' => $this->cashierSessionNumber($shift),
                'cashier_id' => (string) $shift->cashier_id,
                'cashier_name' => $cashierName,
                'cashier_email' => $shift->cashier?->email,
                'register_name' => $shift->cashRegister?->name,
                'register_code' => $shift->cashRegister?->code,
                'status' => $status,
                'orders_count' => $sales->count(),
                'sales_total' => $invoiced,
                'duration_seconds' => $durationSeconds,
                'opened_at' => $openedAt?->toIso8601String(),
                'closed_at' => $closedAt?->toIso8601String(),
            ],
            'summary' => [
                'orders_count' => $sales->count(),
                'invoiced_total' => $invoiced,
                'collected_total' => $collected,
                'credit_total' => $credit,
                'products_count' => count($products),
            ],
            'orders' => $orders,
            'products' => $products,
        ];
    }

    private function cashierSessionNumber(CashierShift $shift): string
    {
        $date = $shift->opened_at?->format('Ymd') ?: now()->format('Ymd');
        $suffix = strtoupper(substr(preg_replace('/[^0-9a-f]/i', '', (string) $shift->id) ?: '0000', -4));
        $numeric = sprintf('%04d', hexdec($suffix) % 10000);

        return 'SH-'.$date.'-'.$numeric;
    }

    /**
     * @return array<string, mixed>
     */
    public function userPerformanceDetail(string $userId, ?string $storeId, ?Carbon $from, ?Carbon $to): array
    {
        $fromBound = $from ? $this->boundStart($from) : now()->copy()->startOfMonth()->startOfDay();
        $toBound = $to ? $this->boundEnd($to) : now()->copy()->endOfDay();

        $user = User::query()->with(['roles:id,name,slug'])->findOrFail($userId);

        $salesQuery = Sale::query()
            ->where('status', 'completed')
            ->where('processed_by', $userId);
        if ($storeId) {
            $salesQuery->where('store_id', $storeId);
        }
        $sales = $salesQuery
            ->where('completed_at', '>=', $fromBound)
            ->where('completed_at', '<=', $toBound)
            ->with([
                'customer:id,name',
                'invoices:id,sale_id,invoice_number,status',
                'cashierShift.cashier:id,name',
            ])
            ->orderByDesc('completed_at')
            ->get([
                'id', 'reference', 'status', 'payment_status', 'customer_id', 'cashier_shift_id',
                'total', 'paid_amount', 'tax_total', 'discount_total', 'subtotal', 'completed_at',
            ]);

        $saleIds = $sales->pluck('id')->map(fn ($id) => (string) $id)->all();
        $houseBySale = $this->houseOfferBySaleIds($saleIds);
        $cashierBySale = $this->cashierNamesBySaleIds($sales);
        $products = $this->dailyProducts($saleIds);
        $payments = $this->dailyPayments($saleIds);
        $customers = $this->userPerformanceCustomers($sales);

        $invoiced = (int) $sales->sum('total');
        $collected = (int) $sales->sum('paid_amount');
        $credit = (int) $sales->sum(fn (Sale $sale) => max(0, (int) $sale->total - (int) $sale->paid_amount));
        $taxTotal = (int) $sales->sum('tax_total');
        $discountTotal = (int) $sales->sum('discount_total');
        $houseOffer = (int) array_sum($houseBySale);

        $openOrdersQuery = Sale::query()
            ->whereIn('status', ['draft', 'pending'])
            ->where('processed_by', $userId);
        if ($storeId) {
            $openOrdersQuery->where('store_id', $storeId);
        }
        $ordersCount = (clone $openOrdersQuery)
            ->where('created_at', '>=', $fromBound)
            ->where('created_at', '<=', $toBound)
            ->count();

        $purchaseOrdersCount = 0;
        if (Schema::hasTable('purchase_orders')) {
            $poQuery = PurchaseOrder::query()
                ->where('created_by', $userId)
                ->where('created_at', '>=', $fromBound)
                ->where('created_at', '<=', $toBound);
            if ($storeId && Schema::hasColumn('purchase_orders', 'store_id')) {
                $poQuery->where('store_id', $storeId);
            }
            $purchaseOrdersCount = $poQuery->count();
        }

        $byDayMap = [];
        foreach ($sales as $sale) {
            $day = $sale->completed_at?->format('Y-m-d');
            if (! $day) {
                continue;
            }
            $byDayMap[$day] ??= [
                'day' => $day,
                'invoiced_total' => 0,
                'collected_total' => 0,
                'invoices_count' => 0,
            ];
            $byDayMap[$day]['invoiced_total'] += (int) $sale->total;
            $byDayMap[$day]['collected_total'] += (int) $sale->paid_amount;
            $byDayMap[$day]['invoices_count']++;
        }

        $byDay = [];
        $cursor = $fromBound->copy()->startOfDay();
        $endDay = $toBound->copy()->startOfDay();
        while ($cursor->lte($endDay)) {
            $key = $cursor->toDateString();
            $byDay[] = $byDayMap[$key] ?? [
                'day' => $key,
                'invoiced_total' => 0,
                'collected_total' => 0,
                'invoices_count' => 0,
            ];
            $cursor->addDay();
        }

        $invoices = $sales->map(function (Sale $sale) use ($houseBySale, $cashierBySale) {
            $saleId = (string) $sale->id;
            $invoice = $sale->relationLoaded('invoices') ? $sale->invoices->first() : null;
            $total = (int) $sale->total;
            $paid = (int) $sale->paid_amount;
            $paymentStatus = $sale->payment_status instanceof SalePaymentStatus
                ? $sale->payment_status->value
                : (string) ($sale->payment_status ?? 'unpaid');
            if ($paymentStatus === 'on_credit') {
                $paymentStatus = 'credit';
            }

            return [
                'id' => $saleId,
                'invoice_number' => $invoice?->invoice_number ?: $sale->reference,
                'reference' => $sale->reference,
                'customer_name' => $sale->customer?->name ?: 'POS Walk-in',
                'status' => $sale->status?->value ?? (string) $sale->status,
                'payment_status' => $paymentStatus,
                'cashier_name' => $paid > 0 ? ($cashierBySale[$saleId] ?? null) : null,
                'total' => $total,
                'paid_amount' => $paid,
                'outstanding_amount' => max(0, $total - $paid),
                'house_offer' => (int) ($houseBySale[$saleId] ?? 0),
                'completed_at' => $sale->completed_at?->toIso8601String(),
            ];
        })->values()->all();

        return [
            'from' => $fromBound->toDateTimeString(),
            'to' => $toBound->toDateTimeString(),
            'user' => [
                'user_id' => (string) $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'handle' => '@'.$user->email,
                'role' => $user->roles->first()?->slug ?? $user->roles->first()?->name ?? 'member',
                'role_name' => $user->roles->first()?->name,
            ],
            'summary' => [
                'invoices_count' => $sales->count(),
                'invoiced_total' => $invoiced,
                'collected_total' => $collected,
                'credit_total' => $credit,
                'tax_total' => $taxTotal,
                'discount_total' => $discountTotal,
                'house_offer' => $houseOffer,
                'orders_count' => $ordersCount,
                'purchase_orders_count' => $purchaseOrdersCount,
                'products_count' => count($products),
                'customers_count' => count($customers),
            ],
            'by_day' => $byDay,
            'invoices' => $invoices,
            'products' => $products,
            'customers' => $customers,
            'payments' => $payments,
        ];
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return array<string, string>
     */
    private function cashierNamesBySaleIds(Collection $sales): array
    {
        $map = [];
        foreach ($sales as $sale) {
            $saleId = (string) $sale->id;
            $name = $sale->cashierShift?->cashier?->name;
            if ($name) {
                $map[$saleId] = $name;
            }
        }

        $missing = $sales
            ->filter(fn (Sale $sale) => ! isset($map[(string) $sale->id]) && (int) $sale->paid_amount > 0)
            ->pluck('id')
            ->map(fn ($id) => (string) $id)
            ->values()
            ->all();

        if ($missing !== [] && Schema::hasTable('payment_transactions')) {
            $txns = \App\Models\PaymentTransaction::query()
                ->whereIn('sale_id', $missing)
                ->where('status', 'completed')
                ->with('processedBy:id,name')
                ->orderByDesc('completed_at')
                ->get(['id', 'sale_id', 'processed_by', 'completed_at']);

            foreach ($txns as $txn) {
                $saleId = (string) $txn->sale_id;
                if (isset($map[$saleId])) {
                    continue;
                }
                if ($txn->processedBy?->name) {
                    $map[$saleId] = $txn->processedBy->name;
                }
            }
        }

        return $map;
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array{label: string, invoices: int, revenue: int, unpaid: int}>
     */
    private function userPerformanceCustomers(Collection $sales): array
    {
        $customers = [];
        foreach ($sales as $sale) {
            if (! $sale->customer_id) {
                continue;
            }
            $id = (string) $sale->customer_id;
            $customers[$id] ??= [
                'label' => $sale->customer?->name ?: $id,
                'invoices' => 0,
                'revenue' => 0,
                'unpaid' => 0,
            ];
            $customers[$id]['invoices']++;
            $customers[$id]['revenue'] += (int) $sale->total;
            $customers[$id]['unpaid'] += max(0, (int) $sale->total - (int) $sale->paid_amount);
        }

        $list = array_values($customers);
        usort($list, fn (array $a, array $b) => ($b['revenue'] <=> $a['revenue']));

        return array_slice($list, 0, 40);
    }

    /**
     * @return \Illuminate\Database\Eloquent\Builder<Sale>
     */
    private function completedSalesQuery(?string $storeId, Carbon $from, Carbon $to)
    {
        $query = Sale::query()->where('status', 'completed');

        if ($storeId) {
            $query->where('store_id', $storeId);
        }

        return $query
            ->where('completed_at', '>=', $from)
            ->where('completed_at', '<=', $to);
    }

    /**
     * @param  list<string>  $saleIds
     * @return array<string, int>
     */
    private function cashCollectedBySaleIds(array $saleIds): array
    {
        if ($saleIds === []) {
            return [];
        }

        $payments = SalePayment::query()
            ->whereIn('sale_id', $saleIds)
            ->where('payment_method', SalePaymentMethod::Cash->value)
            ->get(['sale_id', 'amount']);

        $map = [];
        foreach ($payments as $payment) {
            $saleId = (string) $payment->sale_id;
            $map[$saleId] = ($map[$saleId] ?? 0) + (int) $payment->amount;
        }

        return $map;
    }

    /**
     * @param  list<string>  $saleIds
     * @return array<string, int>
     */
    private function houseOfferBySaleIds(array $saleIds): array
    {
        if ($saleIds === [] || ! Schema::hasTable('sale_items')) {
            return [];
        }

        $items = SaleItem::query()
            ->whereIn('sale_id', $saleIds)
            ->get(['sale_id', 'quantity', 'unit_price', 'catalog_price', 'line_total', 'is_accompaniment']);

        $map = [];
        foreach ($items as $item) {
            $lineTotal = (int) $item->line_total;
            $isAccompaniment = (bool) $item->is_accompaniment;
            if (! $isAccompaniment && $lineTotal !== 0) {
                continue;
            }

            $qty = (int) $item->quantity;
            $unitPrice = (int) $item->unit_price;
            $catalogPrice = (int) ($item->catalog_price ?? 0);
            $value = ($catalogPrice > 0 ? $catalogPrice : $unitPrice) * $qty;
            $saleId = (string) $item->sale_id;
            $map[$saleId] = ($map[$saleId] ?? 0) + $value;
        }

        return $map;
    }

    /**
     * @param  list<string>  $saleIds
     * @return array<string, int>
     */
    private function cogsBySaleIds(array $saleIds): array
    {
        if ($saleIds === [] || ! Schema::hasTable('sale_items')) {
            return [];
        }

        $items = SaleItem::query()
            ->whereIn('sale_id', $saleIds)
            ->with(['product:id,cost_price'])
            ->get(['sale_id', 'product_id', 'quantity']);

        $map = [];
        foreach ($items as $item) {
            $cost = $item->product?->cost_price !== null ? (int) $item->product->cost_price : 0;
            $saleId = (string) $item->sale_id;
            $map[$saleId] = ($map[$saleId] ?? 0) + ($cost * (int) $item->quantity);
        }

        return $map;
    }

    /**
     * Product breakdown for a cashier session (qty, avg price, revenue, cost, profit, margin,
     * plus credit / house-offer markers).
     *
     * @param  list<string>  $saleIds
     * @param  array<string, bool>  $saleCreditMap
     * @return list<array<string, mixed>>
     */
    private function sessionProducts(array $saleIds, array $saleCreditMap): array
    {
        if ($saleIds === [] || ! Schema::hasTable('sale_items')) {
            return [];
        }

        $items = SaleItem::query()
            ->whereIn('sale_id', $saleIds)
            ->with(['product:id,name,sku,cost_price'])
            ->get([
                'id', 'sale_id', 'product_id', 'product_name', 'product_sku',
                'quantity', 'unit_price', 'catalog_price', 'line_total', 'is_accompaniment',
            ]);

        $products = [];
        foreach ($items as $item) {
            if ((bool) $item->is_accompaniment) {
                continue;
            }

            $qty = (int) $item->quantity;
            $lineTotal = (int) $item->line_total;
            $unitPrice = (int) $item->unit_price;
            $catalogPrice = (int) ($item->catalog_price ?? 0);
            $isHouseOffer = $lineTotal === 0;
            $displayUnit = $catalogPrice > 0 ? $catalogPrice : $unitPrice;
            $displayRevenue = $isHouseOffer ? ($displayUnit * $qty) : $lineTotal;
            $costPrice = $item->product?->cost_price !== null ? (int) $item->product->cost_price : 0;
            $lineCost = $isHouseOffer ? 0 : ($costPrice * $qty);
            $grossProfit = $isHouseOffer ? 0 : ($lineTotal - $lineCost);
            $baseKey = (string) ($item->product_id ?: ($item->product_name ?: 'article'));
            $key = $isHouseOffer ? $baseKey.'|house' : $baseKey;
            $onCredit = ! $isHouseOffer && ($saleCreditMap[(string) $item->sale_id] ?? false);

            $products[$key] ??= [
                'label' => $item->product?->name ?? $item->product_name ?? $baseKey,
                'sku' => $item->product?->sku ?? $item->product_sku,
                'quantity' => 0,
                'credit_quantity' => 0,
                'house_offer_quantity' => 0,
                'is_house_offer' => $isHouseOffer,
                'unit_price' => 0,
                'revenue' => 0,
                'cost' => 0,
                'gross_profit' => 0,
                '_price_sum' => 0,
                '_price_qty' => 0,
            ];

            $products[$key]['quantity'] += $qty;
            $products[$key]['revenue'] += $displayRevenue;
            $products[$key]['cost'] += $lineCost;
            $products[$key]['gross_profit'] += $grossProfit;
            $products[$key]['_price_sum'] += $displayUnit * $qty;
            $products[$key]['_price_qty'] += $qty;
            if ($isHouseOffer) {
                $products[$key]['house_offer_quantity'] += $qty;
            }
            if ($onCredit) {
                $products[$key]['credit_quantity'] += $qty;
            }
        }

        $list = [];
        foreach ($products as $product) {
            $priceQty = (int) $product['_price_qty'];
            $revenue = (int) $product['revenue'];
            $cost = (int) $product['cost'];
            $grossProfit = (int) $product['gross_profit'];
            $isHouseOffer = (bool) $product['is_house_offer'];
            $list[] = [
                'label' => $product['label'],
                'sku' => $product['sku'],
                'quantity' => (int) $product['quantity'],
                'credit_quantity' => (int) $product['credit_quantity'],
                'house_offer_quantity' => (int) $product['house_offer_quantity'],
                'is_house_offer' => $isHouseOffer,
                'unit_price' => $priceQty > 0 ? (int) round(((int) $product['_price_sum']) / $priceQty) : 0,
                'revenue' => $revenue,
                'cost' => $cost,
                'gross_profit' => $grossProfit,
                'margin_pct' => $isHouseOffer
                    ? 0.0
                    : ($revenue > 0 ? round(($grossProfit / $revenue) * 1000) / 10 : ($cost === 0 ? 100.0 : 0.0)),
            ];
        }

        usort($list, function (array $a, array $b) {
            $cmp = ((int) $b['quantity']) <=> ((int) $a['quantity']);
            if ($cmp !== 0) {
                return $cmp;
            }

            return ((int) $b['revenue']) <=> ((int) $a['revenue']);
        });

        return $list;
    }

    /**
     * @param  list<string>  $saleIds
     * @return list<array<string, mixed>>
     */
    private function dailyProducts(array $saleIds): array
    {
        if ($saleIds === [] || ! Schema::hasTable('sale_items')) {
            return [];
        }

        $items = SaleItem::query()
            ->whereIn('sale_id', $saleIds)
            ->with(['product:id,name,sku,cost_price'])
            ->get([
                'id', 'sale_id', 'product_id', 'product_name', 'product_sku',
                'quantity', 'unit_price', 'line_total', 'is_accompaniment',
            ]);

        $products = [];
        foreach ($items as $item) {
            if ((bool) $item->is_accompaniment) {
                continue;
            }

            $qty = (int) $item->quantity;
            $lineTotal = (int) $item->line_total;
            $unitPrice = (int) $item->unit_price;
            $costPrice = $item->product?->cost_price !== null ? (int) $item->product->cost_price : 0;
            $lineCost = $costPrice * $qty;
            $grossProfit = $lineTotal - $lineCost;
            $key = (string) ($item->product_id ?: ($item->product_name ?: 'article'));

            $products[$key] ??= [
                'label' => $item->product?->name ?? $item->product_name ?? $key,
                'sku' => $item->product?->sku ?? $item->product_sku,
                'quantity' => 0,
                'unit_price' => 0,
                'revenue' => 0,
                'gross_profit' => 0,
                '_price_sum' => 0,
                '_price_qty' => 0,
            ];

            $products[$key]['quantity'] += $qty;
            $products[$key]['revenue'] += $lineTotal;
            $products[$key]['gross_profit'] += $grossProfit;
            $products[$key]['_price_sum'] += $unitPrice * $qty;
            $products[$key]['_price_qty'] += $qty;
        }

        $list = [];
        foreach ($products as $product) {
            $priceQty = (int) $product['_price_qty'];
            $revenue = (int) $product['revenue'];
            $grossProfit = (int) $product['gross_profit'];
            $list[] = [
                'label' => $product['label'],
                'sku' => $product['sku'],
                'quantity' => (int) $product['quantity'],
                'unit_price' => $priceQty > 0 ? (int) round(((int) $product['_price_sum']) / $priceQty) : 0,
                'revenue' => $revenue,
                'gross_profit' => $grossProfit,
                'margin_pct' => $revenue > 0
                    ? round(($grossProfit / $revenue) * 1000) / 10
                    : 100.0,
            ];
        }

        usort($list, fn (array $a, array $b) => ((int) $b['revenue']) <=> ((int) $a['revenue']));

        return $list;
    }

    /**
     * @param  list<string>  $saleIds
     * @return list<array<string, mixed>>
     */
    private function dailyPayments(array $saleIds): array
    {
        if ($saleIds === []) {
            return [];
        }

        $saleLabels = Sale::query()
            ->whereIn('id', $saleIds)
            ->with(['invoices:id,sale_id,invoice_number'])
            ->get(['id', 'reference'])
            ->mapWithKeys(function (Sale $sale) {
                $invoice = $sale->invoices->first();

                return [
                    (string) $sale->id => $invoice?->invoice_number ?: (string) $sale->reference,
                ];
            })
            ->all();

        if (Schema::hasTable('payment_transactions')) {
            $txns = \App\Models\PaymentTransaction::query()
                ->whereIn('sale_id', $saleIds)
                ->orderBy('completed_at')
                ->orderBy('created_at')
                ->get([
                    'id', 'sale_id', 'transaction_number', 'payment_method',
                    'amount', 'provider_reference', 'completed_at',
                ]);

            if ($txns->isNotEmpty()) {
                return $txns->map(function ($txn) use ($saleLabels) {
                    $code = (string) ($txn->payment_method instanceof SalePaymentMethod
                        ? $txn->payment_method->value
                        : $txn->payment_method);

                    return [
                        'id' => (string) $txn->id,
                        'payment_number' => $txn->transaction_number,
                        'sale_id' => (string) $txn->sale_id,
                        'invoice_number' => $saleLabels[(string) $txn->sale_id] ?? null,
                        'payment_method' => $code,
                        'label' => SalePaymentMethod::tryFrom($code)?->label()
                            ?? ($code !== '' ? ucfirst(str_replace('_', ' ', $code)) : 'Other'),
                        'reference' => $txn->provider_reference,
                        'amount' => (int) $txn->amount,
                        'completed_at' => $txn->completed_at?->toIso8601String(),
                    ];
                })->values()->all();
            }
        }

        $payments = SalePayment::query()
            ->whereIn('sale_id', $saleIds)
            ->orderBy('sort_order')
            ->get(['id', 'sale_id', 'payment_method', 'amount', 'payment_transaction_id']);

        return $payments->map(function (SalePayment $payment) use ($saleLabels) {
            $code = (string) ($payment->payment_method instanceof SalePaymentMethod
                ? $payment->payment_method->value
                : $payment->payment_method);

            return [
                'id' => (string) $payment->id,
                'payment_number' => $payment->payment_transaction_id,
                'sale_id' => (string) $payment->sale_id,
                'invoice_number' => $saleLabels[(string) $payment->sale_id] ?? null,
                'payment_method' => $code,
                'label' => SalePaymentMethod::tryFrom($code)?->label()
                    ?? ($code !== '' ? ucfirst(str_replace('_', ' ', $code)) : 'Other'),
                'reference' => null,
                'amount' => (int) $payment->amount,
                'completed_at' => null,
            ];
        })->values()->all();
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array<string, mixed>>
     */
    private function condensedByPaymentMethod(Collection $sales): array
    {
        if ($sales->isEmpty()) {
            return [];
        }

        $payments = SalePayment::query()
            ->whereIn('sale_id', $sales->pluck('id'))
            ->get(['payment_method', 'amount']);

        $grouped = [];
        foreach ($payments as $payment) {
            $code = (string) ($payment->payment_method instanceof SalePaymentMethod
                ? $payment->payment_method->value
                : $payment->payment_method);
            $grouped[$code] ??= [
                'payment_method' => $code,
                'amount' => 0,
                'count' => 0,
            ];
            $grouped[$code]['amount'] += (int) $payment->amount;
            $grouped[$code]['count']++;
        }

        $labels = CompanyPaymentMethod::query()
            ->whereIn('code', array_keys($grouped))
            ->get(['code', 'label', 'label_fr'])
            ->keyBy('code');

        $total = array_sum(array_column($grouped, 'amount'));
        $rows = array_values($grouped);
        usort($rows, fn (array $a, array $b) => $b['amount'] <=> $a['amount']);

        return array_map(function (array $row) use ($total, $labels) {
            $code = $row['payment_method'];
            $company = $labels->get($code);
            $row['label'] = $company
                ? (string) ($company->label_fr ?: $company->label ?: $code)
                : (SalePaymentMethod::tryFrom($code)?->label()
                    ?? ($code !== '' ? str_replace('_', ' ', $code) : 'Other'));
            $row['share'] = $total > 0 ? round($row['amount'] / $total * 1000) / 10 : 0.0;

            return $row;
        }, $rows);
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array<string, mixed>>
     */
    private function condensedByPaymentStatus(Collection $sales, int $totalBilled): array
    {
        $grouped = [];
        foreach ($sales as $sale) {
            $status = $sale->payment_status instanceof SalePaymentStatus
                ? $sale->payment_status->value
                : (string) ($sale->payment_status ?? 'unpaid');

            $grouped[$status] ??= [
                'payment_status' => $status,
                'amount' => 0,
                'count' => 0,
            ];
            $grouped[$status]['amount'] += (int) $sale->total;
            $grouped[$status]['count']++;
        }

        $order = [
            SalePaymentStatus::Paid->value,
            SalePaymentStatus::Partial->value,
            SalePaymentStatus::OnCredit->value,
            SalePaymentStatus::Unpaid->value,
        ];

        $rows = [];
        foreach ($order as $status) {
            if (! isset($grouped[$status])) {
                continue;
            }
            $row = $grouped[$status];
            $row['share'] = $totalBilled > 0 ? round($row['amount'] / $totalBilled * 1000) / 10 : 0.0;
            $rows[] = $row;
        }

        foreach ($grouped as $status => $row) {
            if (in_array($status, $order, true)) {
                continue;
            }
            $row['share'] = $totalBilled > 0 ? round($row['amount'] / $totalBilled * 1000) / 10 : 0.0;
            $rows[] = $row;
        }

        return $rows;
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
     * @return list<array{weekday: int, label: string, sales_count: int, revenue: int}>
     */
    private function salesByWeekday(Collection $sales): array
    {
        $buckets = [];
        for ($day = 1; $day <= 7; $day++) {
            $buckets[$day] = [
                'weekday' => $day,
                'label' => (string) $day,
                'sales_count' => 0,
                'revenue' => 0,
            ];
        }

        foreach ($sales as $sale) {
            if ($sale->completed_at === null) {
                continue;
            }
            $day = (int) $sale->completed_at->dayOfWeekIso;
            $buckets[$day]['sales_count']++;
            $buckets[$day]['revenue'] += (int) $sale->total;
        }

        return array_values($buckets);
    }

    /**
     * @param  Collection<int, array<string, mixed>>|iterable<int, array<string, mixed>>  $byDay
     * @return list<array{day: string, aov: int, sales_count: int, revenue: int}>
     */
    private function aovByDay(iterable $byDay): array
    {
        $rows = [];
        foreach ($byDay as $row) {
            $count = (int) ($row['sales_count'] ?? 0);
            $revenue = (int) ($row['revenue'] ?? 0);
            $rows[] = [
                'day' => (string) ($row['day'] ?? ''),
                'sales_count' => $count,
                'revenue' => $revenue,
                'aov' => $count > 0 ? (int) round($revenue / $count) : 0,
            ];
        }

        return $rows;
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return array{
     *   by_product: list<array<string, mixed>>,
     *   by_category: list<array<string, mixed>>,
     *   by_cashier: list<array<string, mixed>>,
     *   by_customer: list<array<string, mixed>>
     * }
     */
    private function salesDimensions(Collection $sales): array
    {
        if ($sales->isEmpty()) {
            return [
                'by_product' => [],
                'by_category' => [],
                'by_cashier' => [],
                'by_customer' => [],
                'by_location' => [],
                'customer_summary' => [
                    'customers' => 0,
                    'revenue' => 0,
                    'unpaid' => 0,
                    'avg_revenue' => 0,
                ],
            ];
        }

        $products = [];
        $categories = [];
        if (Schema::hasTable('sale_items')) {
            $items = SaleItem::query()
                ->whereIn('sale_id', $sales->pluck('id'))
                ->with(['product:id,name,sku,category_id', 'product.category:id,name'])
                ->get(['id', 'sale_id', 'product_id', 'product_name', 'product_sku', 'quantity', 'line_total']);

            foreach ($items as $item) {
                $category = $item->product?->category?->name;
                $productKey = $item->product_id ?: ($item->product_name ?: 'article');
                $products[$productKey] ??= [
                    'label' => $item->product?->name ?? $item->product_name ?? $productKey,
                    'sku' => $item->product?->sku ?? $item->product_sku,
                    'category' => $category,
                    'quantity' => 0,
                    'revenue' => 0,
                    'orders' => 0,
                    '_sale_ids' => [],
                ];
                $products[$productKey]['quantity'] += (int) $item->quantity;
                $products[$productKey]['revenue'] += (int) $item->line_total;
                $products[$productKey]['_sale_ids'][(string) $item->sale_id] = true;

                $categoryKey = $category ?: '';
                $categories[$categoryKey] ??= [
                    'label' => $category,
                    'quantity' => 0,
                    'revenue' => 0,
                    'orders' => 0,
                    '_sale_ids' => [],
                ];
                $categories[$categoryKey]['quantity'] += (int) $item->quantity;
                $categories[$categoryKey]['revenue'] += (int) $item->line_total;
                $categories[$categoryKey]['_sale_ids'][(string) $item->sale_id] = true;
            }

            foreach ($products as &$product) {
                $product['orders'] = count($product['_sale_ids']);
                $qty = (int) $product['quantity'];
                $product['avg_price'] = $qty > 0 ? (int) round(((int) $product['revenue']) / $qty) : 0;
                unset($product['_sale_ids']);
            }
            unset($product);

            $categoryRevenueTotal = array_sum(array_map(fn (array $row) => (int) $row['revenue'], $categories));
            foreach ($categories as &$categoryRow) {
                $categoryRow['orders'] = count($categoryRow['_sale_ids']);
                $qty = (int) $categoryRow['quantity'];
                $revenue = (int) $categoryRow['revenue'];
                $categoryRow['avg_price'] = $qty > 0 ? (int) round($revenue / $qty) : 0;
                $categoryRow['share'] = $categoryRevenueTotal > 0
                    ? round(($revenue / $categoryRevenueTotal) * 1000) / 10
                    : 0;
                unset($categoryRow['_sale_ids']);
            }
            unset($categoryRow);
        }

        $names = User::query()
            ->whereIn('id', $sales->pluck('processed_by')->filter()->unique()->all())
            ->pluck('name', 'id');
        $cashiers = [];
        $customers = [];
        $sales->loadMissing([
            'customer:id,name',
            'customer.addresses' => fn ($q) => $q->orderByDesc('is_primary')->limit(1),
        ]);
        foreach ($sales as $sale) {
            $id = (string) ($sale->processed_by ?? '');
            $cashiers[$id] ??= [
                'label' => $id === '' ? null : ($names[$id] ?? $id),
                'sales_count' => 0,
                'revenue' => 0,
            ];
            $cashiers[$id]['sales_count']++;
            $cashiers[$id]['revenue'] += (int) $sale->total;

            $customerId = (string) ($sale->customer_id ?? '');
            $address = $sale->customer?->addresses?->first();
            $location = $address
                ? trim(implode(', ', array_filter([(string) ($address->city ?? ''), (string) ($address->country_code ?? '')])))
                : null;
            $customers[$customerId] ??= [
                'label' => $customerId === '' ? null : ($sale->customer?->name ?? $customerId),
                'location' => $location ?: null,
                'invoices' => 0,
                'sales_count' => 0,
                'revenue' => 0,
                'unpaid' => 0,
                'last_purchase' => null,
            ];
            $customers[$customerId]['invoices']++;
            $customers[$customerId]['sales_count']++;
            $customers[$customerId]['revenue'] += (int) $sale->total;
            $customers[$customerId]['unpaid'] += max(0, (int) $sale->total - (int) $sale->paid_amount);
            $purchaseAt = $sale->completed_at?->toDateString();
            if ($purchaseAt && ($customers[$customerId]['last_purchase'] === null || $purchaseAt > $customers[$customerId]['last_purchase'])) {
                $customers[$customerId]['last_purchase'] = $purchaseAt;
            }
            if (! $customers[$customerId]['location'] && $location) {
                $customers[$customerId]['location'] = $location;
            }
        }

        $byLocation = [];
        foreach ($customers as $customer) {
            $locKey = (string) ($customer['location'] ?? '');
            $byLocation[$locKey] ??= [
                'label' => $customer['location'],
                'customers' => 0,
                'revenue' => 0,
                'unpaid' => 0,
            ];
            $byLocation[$locKey]['customers']++;
            $byLocation[$locKey]['revenue'] += (int) $customer['revenue'];
            $byLocation[$locKey]['unpaid'] += (int) $customer['unpaid'];
        }
        $locationTotal = array_sum(array_map(fn (array $row) => (int) $row['revenue'], $byLocation));
        foreach ($byLocation as &$locRow) {
            $revenue = (int) $locRow['revenue'];
            $locRow['share'] = $locationTotal > 0 ? round(($revenue / $locationTotal) * 1000) / 10 : 0;
        }
        unset($locRow);

        $identifiedCustomers = array_filter($customers, fn (array $row) => ($row['label'] ?? null) !== null);
        $customerRevenue = (int) array_sum(array_map(fn (array $row) => (int) $row['revenue'], $identifiedCustomers));
        $customerUnpaid = (int) array_sum(array_map(fn (array $row) => (int) $row['unpaid'], $identifiedCustomers));
        $customerCount = count($identifiedCustomers);

        return [
            'by_product' => $this->ranked($products),
            'by_category' => $this->ranked($categories),
            'by_cashier' => $this->ranked($cashiers),
            'by_customer' => $this->ranked($customers),
            'by_location' => $this->ranked($byLocation),
            'customer_summary' => [
                'customers' => $customerCount,
                'revenue' => $customerRevenue,
                'unpaid' => $customerUnpaid,
                'avg_revenue' => $customerCount > 0 ? (int) round($customerRevenue / $customerCount) : 0,
            ],
        ];
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array{label: string, collected: int, unpaid: int, revenue: int}>
     */
    private function monthlyRevenueBreakdown(Collection $sales): array
    {
        return $sales
            ->groupBy(fn (Sale $sale) => $sale->completed_at?->format('Y-m') ?? '—')
            ->map(function (Collection $group, string $label) {
                $revenue = (int) $group->sum('total');
                $collected = (int) $group->sum('paid_amount');

                return [
                    'label' => $label,
                    'collected' => $collected,
                    'unpaid' => max(0, $revenue - $collected),
                    'revenue' => $revenue,
                ];
            })
            ->sortBy('label')
            ->values()
            ->all();
    }

    /**
     * @return list<array{label: string, count: int}>
     */
    private function invoiceStatusDistribution(?string $storeId, ?Carbon $from, ?Carbon $to): array
    {
        if (! Schema::hasTable('sale_invoices')) {
            return [];
        }

        $query = SaleInvoice::query()->select('status', DB::raw('COUNT(*) as total'));
        if ($storeId || $from || $to) {
            $query->whereHas('sale', function ($saleQuery) use ($storeId, $from, $to) {
                if ($storeId) {
                    $saleQuery->where('store_id', $storeId);
                }
                if ($from) {
                    $saleQuery->where(function ($q) use ($from) {
                        $q->where('completed_at', '>=', $from->copy()->startOfDay())
                            ->orWhere('created_at', '>=', $from->copy()->startOfDay());
                    });
                }
                if ($to) {
                    $saleQuery->where(function ($q) use ($to) {
                        $q->where('completed_at', '<=', $to->copy()->endOfDay())
                            ->orWhere('created_at', '<=', $to->copy()->endOfDay());
                    });
                }
            });
        }

        return $query
            ->groupBy('status')
            ->get()
            ->map(fn ($row) => [
                'label' => is_string($row->status) ? $row->status : (string) ($row->status?->value ?? $row->status),
                'count' => (int) $row->total,
            ])
            ->values()
            ->all();
    }

    /**
     * @return list<array{label: string, count: int}>
     */
    private function orderStatusDistribution(?string $storeId, ?Carbon $from, ?Carbon $to): array
    {
        $query = Sale::query()->select('status', DB::raw('COUNT(*) as total'));
        if ($storeId) {
            $query->where('store_id', $storeId);
        }
        if ($from) {
            $query->where('created_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $query->where('created_at', '<=', $to->copy()->endOfDay());
        }

        return $query
            ->groupBy('status')
            ->get()
            ->map(fn ($row) => [
                'label' => is_string($row->status) ? $row->status : (string) ($row->status?->value ?? $row->status),
                'count' => (int) $row->total,
            ])
            ->values()
            ->all();
    }

    /**
     * @param  Collection<int, SaleReturn>  $returns
     * @return list<array{label: string, count: int, amount: int}>
     */
    private function returnsByType(Collection $returns): array
    {
        return $returns
            ->groupBy(fn (SaleReturn $ret) => trim((string) ($ret->reason ?: '')) ?: 'other')
            ->map(fn (Collection $group, string $label) => [
                'label' => $label,
                'count' => $group->count(),
                'amount' => (int) $group->sum('total'),
            ])
            ->sortByDesc('amount')
            ->values()
            ->all();
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

    private function boundStart(Carbon $from): Carbon
    {
        return $from->copy()->format('H:i:s') === '00:00:00'
            ? $from->copy()->startOfDay()
            : $from->copy();
    }

    private function boundEnd(Carbon $to): Carbon
    {
        return $to->copy()->format('H:i:s') === '00:00:00'
            ? $to->copy()->endOfDay()
            : $to->copy();
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
            ->map(function (StockBalance $balance) {
                $expiresAt = $balance->batch?->expires_at;
                $daysLeft = $expiresAt
                    ? (int) now()->startOfDay()->diffInDays($expiresAt->copy()->startOfDay(), false)
                    : null;

                return [
                    'sku' => $balance->product?->sku,
                    'name' => $balance->product?->name,
                    'warehouse' => $balance->warehouse?->name,
                    'batch' => $balance->batch?->batch_number,
                    'expires_at' => $expiresAt?->toDateString(),
                    'days_left' => $daysLeft,
                    'quantity_on_hand' => (int) $balance->quantity_on_hand,
                    'expired' => $expiresAt?->isPast() ?? false,
                ];
            })
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

    /** @return array<string, mixed> */
    private function emptyPurchasesSummary(): array
    {
        return [
            'total_spend' => 0,
            'orders_count' => 0,
            'suppliers_count' => 0,
            'months_span' => 12,
            'average_order_value' => 0,
            'monthly_spend' => [],
            'order_status' => [],
            'top_categories' => [],
            'by_supplier' => [],
            'supplier_concentration' => [
                'top_count' => 5,
                'share' => 0,
                'spend' => 0,
            ],
            'receipt_summary' => $this->emptyReceiptSummary(),
            'receipts' => [],
            'receipts_count' => 0,
        ];
    }

    /**
     * @param  Collection<int, PurchaseOrder>  $orders
     * @return list<array{label: string, orders_count: int, spend: int}>
     */
    private function purchaseMonthlySpend(Collection $orders, ?Carbon $from, ?Carbon $to): array
    {
        $start = ($from ?? $orders->min('created_at')?->copy() ?? now()->subMonths(11))->copy()->startOfMonth();
        $end = ($to ?? $orders->max('created_at')?->copy() ?? now())->copy()->startOfMonth();

        if ($start->gt($end)) {
            [$start, $end] = [$end, $start];
        }

        $grouped = $orders->groupBy(fn (PurchaseOrder $order) => $order->created_at?->format('Y-m') ?? 'unknown');
        $rows = [];
        $cursor = $start->copy();

        while ($cursor->lte($end)) {
            $label = $cursor->format('Y-m');
            $bucket = $grouped->get($label, collect());
            $rows[] = [
                'label' => $label,
                'orders_count' => $bucket->count(),
                'spend' => (int) $bucket->sum('total'),
            ];
            $cursor->addMonth();
        }

        return $rows;
    }

    /**
     * @param  Collection<int, PurchaseOrder>  $orders
     * @return list<array{label: string, count: int}>
     */
    private function purchaseOrderStatusDistribution(Collection $orders): array
    {
        return $orders
            ->groupBy(fn (PurchaseOrder $order) => $order->status?->value ?? (string) $order->status)
            ->map(fn (Collection $group, string $label) => [
                'label' => $label,
                'count' => $group->count(),
            ])
            ->sortByDesc('count')
            ->values()
            ->all();
    }

    /**
     * @param  Collection<int, PurchaseOrder>  $orders
     * @return list<array{label: string|null, spend: int, quantity: int, share: int}>
     */
    private function purchaseTopCategories(Collection $orders): array
    {
        if ($orders->isEmpty() || ! Schema::hasTable('purchase_order_items')) {
            return [];
        }

        $items = PurchaseOrderItem::query()
            ->whereIn('purchase_order_id', $orders->pluck('id'))
            ->with(['product:id,category_id', 'product.category:id,name'])
            ->get(['id', 'purchase_order_id', 'product_id', 'quantity_ordered', 'line_total']);

        $total = max(1, (int) $items->sum('line_total'));

        return $items
            ->groupBy(fn (PurchaseOrderItem $item) => $item->product?->category?->name ?? '')
            ->map(function (Collection $group, string $label) use ($total) {
                $spend = (int) $group->sum('line_total');

                return [
                    'label' => $label !== '' ? $label : null,
                    'spend' => $spend,
                    'quantity' => (int) $group->sum('quantity_ordered'),
                    'share' => (int) round(($spend / $total) * 100),
                ];
            })
            ->sortByDesc('spend')
            ->take(10)
            ->values()
            ->all();
    }

    /**
     * @param  Collection<int, PurchaseOrder>  $orders
     * @return list<array{label: string|null, code: string|null, location: string|null, orders_count: int, avg_order: int, spend: int, share: int, last_order: string|null}>
     */
    private function purchaseBySupplier(Collection $orders, int $totalSpend): array
    {
        $denominator = max(1, $totalSpend);

        return $orders
            ->groupBy(fn (PurchaseOrder $order) => $order->supplier_id ?? 'none')
            ->map(function (Collection $group) use ($denominator) {
                /** @var PurchaseOrder $first */
                $first = $group->first();
                $last = $group->sortByDesc('created_at')->first();
                $count = $group->count();
                $spend = (int) $group->sum('total');

                return [
                    'label' => $first?->supplier?->name,
                    'code' => $first?->supplier?->code,
                    'location' => $this->supplierLocation($first?->supplier),
                    'orders_count' => $count,
                    'avg_order' => $count > 0 ? (int) round($spend / $count) : 0,
                    'spend' => $spend,
                    'share' => (int) round(($spend / $denominator) * 100),
                    'last_order' => $last?->created_at?->toDateString(),
                ];
            })
            ->sortByDesc('spend')
            ->values()
            ->all();
    }

    /**
     * @param  list<array{spend: int}>  $bySupplier
     * @return array{top_count: int, share: int, spend: int}
     */
    private function purchaseSupplierConcentration(array $bySupplier, int $totalSpend): array
    {
        $topCount = 5;
        $topSpend = (int) collect($bySupplier)->take($topCount)->sum('spend');

        return [
            'top_count' => $topCount,
            'spend' => $topSpend,
            'share' => $totalSpend > 0 ? (int) round(($topSpend / $totalSpend) * 100) : 0,
        ];
    }

    private function supplierLocation(?\App\Models\Supplier $supplier): ?string
    {
        $address = $supplier?->address;
        if (! is_array($address)) {
            return null;
        }

        $parts = array_values(array_filter([
            $address['city'] ?? null,
            $address['country'] ?? $address['country_code'] ?? null,
        ], fn ($part) => is_string($part) && trim($part) !== ''));

        if ($parts !== []) {
            return implode(', ', $parts);
        }

        $line1 = $address['line1'] ?? null;

        return is_string($line1) && trim($line1) !== '' ? $line1 : null;
    }

    /**
     * @return array{
     *   summary: array<string, mixed>,
     *   receipts: list<array<string, mixed>>
     * }
     */
    private function purchaseReceiptBundle(?Carbon $from, ?Carbon $to): array
    {
        if (! Schema::hasTable('goods_receipts')) {
            return [
                'summary' => $this->emptyReceiptSummary(),
                'receipts' => [],
            ];
        }

        $query = GoodsReceipt::query()
            ->with([
                'warehouse:id,name',
                'purchaseOrder:id,supplier_id,order_number',
                'purchaseOrder.supplier:id,name',
                'items:id,goods_receipt_id,purchase_order_item_id,quantity_received,unit_cost',
                'items.purchaseOrderItem:id,quantity_ordered,quantity_received',
            ])
            ->orderByDesc('received_at')
            ->limit(200);

        if ($from) {
            $query->where('received_at', '>=', $from->copy()->startOfDay());
        }
        if ($to) {
            $query->where('received_at', '<=', $to->copy()->endOfDay());
        }

        $rows = $query->get();

        $receipts = $rows->map(function (GoodsReceipt $receipt) {
            $qtyReceived = (int) $receipt->items->sum('quantity_received');
            $qtyOrdered = (int) $receipt->items
                ->groupBy('purchase_order_item_id')
                ->map(fn ($group) => (int) ($group->first()->purchaseOrderItem?->quantity_ordered ?? 0))
                ->sum();

            // Without QC fields yet: completed receipts count as accepted, cancelled as rejected.
            $isCancelled = ($receipt->status?->value ?? (string) $receipt->status) === 'cancelled';
            $qtyAccepted = $isCancelled ? 0 : $qtyReceived;
            $qtyRejected = $isCancelled ? $qtyReceived : 0;
            $qtyQuarantine = 0;

            $amount = (int) $receipt->items->sum(
                fn ($item) => (int) $item->quantity_received * (int) $item->unit_cost
            );

            return [
                'id' => $receipt->id,
                'receipt_number' => $receipt->receipt_number,
                'order_number' => $receipt->purchaseOrder?->order_number,
                'supplier' => $receipt->purchaseOrder?->supplier?->name,
                'warehouse' => $receipt->warehouse?->name,
                'status' => $receipt->status?->value ?? (string) $receipt->status,
                'received_at' => $receipt->received_at?->toIso8601String(),
                'qty_ordered' => $qtyOrdered,
                'qty_received' => $qtyReceived,
                'qty_accepted' => $qtyAccepted,
                'qty_rejected' => $qtyRejected,
                'qty_quarantine' => $qtyQuarantine,
                'inspection' => null,
                'amount' => $amount,
                'items_count' => $receipt->items->count(),
            ];
        })->values();

        $qtyOrdered = (int) $receipts->sum('qty_ordered');
        $qtyReceived = (int) $receipts->sum('qty_received');
        $qtyAccepted = (int) $receipts->sum('qty_accepted');
        $qtyRejected = (int) $receipts->sum('qty_rejected');
        $qtyQuarantine = (int) $receipts->sum('qty_quarantine');
        $base = max(1, $qtyOrdered);

        $statusDistribution = $receipts
            ->groupBy('status')
            ->map(fn (Collection $group, string $label) => [
                'label' => $label,
                'count' => $group->count(),
            ])
            ->sortByDesc('count')
            ->values()
            ->all();

        return [
            'summary' => [
                'total_receipts' => $receipts->count(),
                'qty_ordered' => $qtyOrdered,
                'qty_received' => $qtyReceived,
                'qty_accepted' => $qtyAccepted,
                'qty_rejected' => $qtyRejected,
                'qty_quarantine' => $qtyQuarantine,
                'quantity_breakdown' => [
                    ['label' => 'ordered', 'qty' => $qtyOrdered, 'share' => round(($qtyOrdered / $base) * 100, 1)],
                    ['label' => 'received', 'qty' => $qtyReceived, 'share' => round(($qtyReceived / $base) * 100, 1)],
                    ['label' => 'accepted', 'qty' => $qtyAccepted, 'share' => round(($qtyAccepted / $base) * 100, 1)],
                    ['label' => 'rejected', 'qty' => $qtyRejected, 'share' => round(($qtyRejected / $base) * 100, 1)],
                    ['label' => 'quarantine', 'qty' => $qtyQuarantine, 'share' => round(($qtyQuarantine / $base) * 100, 1)],
                ],
                'receipt_status' => $statusDistribution,
                'inspection_results' => [],
            ],
            'receipts' => $receipts->all(),
        ];
    }

    /** @return array<string, mixed> */
    private function emptyReceiptSummary(): array
    {
        return [
            'total_receipts' => 0,
            'qty_ordered' => 0,
            'qty_received' => 0,
            'qty_accepted' => 0,
            'qty_rejected' => 0,
            'qty_quarantine' => 0,
            'quantity_breakdown' => [
                ['label' => 'ordered', 'qty' => 0, 'share' => 0.0],
                ['label' => 'received', 'qty' => 0, 'share' => 0.0],
                ['label' => 'accepted', 'qty' => 0, 'share' => 0.0],
                ['label' => 'rejected', 'qty' => 0, 'share' => 0.0],
                ['label' => 'quarantine', 'qty' => 0, 'share' => 0.0],
            ],
            'receipt_status' => [],
            'inspection_results' => [],
        ];
    }

    /**
     * @param  Collection<int, Sale>  $sales
     * @return list<array{label: string, sku: string|null, previous: int, current: int, growth: float}>
     */
    private function forecastGrowingProducts(Collection $sales): array
    {
        if ($sales->isEmpty() || ! Schema::hasTable('sale_items')) {
            return [];
        }

        $currentMonth = now()->format('Y-m');
        $previousMonth = now()->copy()->subMonth()->format('Y-m');

        $salesById = $sales->keyBy('id');
        $items = SaleItem::query()
            ->whereIn('sale_id', $sales->pluck('id'))
            ->with(['product:id,name,sku'])
            ->get(['id', 'sale_id', 'product_id', 'product_name', 'product_sku', 'line_total']);

        $map = [];
        foreach ($items as $item) {
            $sale = $salesById->get($item->sale_id);
            $month = $sale?->completed_at?->format('Y-m');
            if (! in_array($month, [$currentMonth, $previousMonth], true)) {
                continue;
            }

            $key = (string) ($item->product_id ?: ($item->product_name ?: 'article'));
            $map[$key] ??= [
                'label' => $item->product?->name ?? $item->product_name ?? $key,
                'sku' => $item->product?->sku ?? $item->product_sku,
                'previous' => 0,
                'current' => 0,
            ];
            if ($month === $currentMonth) {
                $map[$key]['current'] += (int) $item->line_total;
            } else {
                $map[$key]['previous'] += (int) $item->line_total;
            }
        }

        return collect($map)
            ->map(function (array $row) {
                $prev = (int) $row['previous'];
                $curr = (int) $row['current'];
                $growth = $prev > 0
                    ? (($curr - $prev) / $prev) * 100
                    : ($curr > 0 ? 100.0 : 0.0);

                return [
                    'label' => $row['label'],
                    'sku' => $row['sku'],
                    'previous' => $prev,
                    'current' => $curr,
                    'growth' => round($growth, 1),
                ];
            })
            ->filter(fn (array $row) => $row['previous'] > 0 || $row['current'] > 0)
            ->sortByDesc('growth')
            ->take(8)
            ->values()
            ->all();
    }
}
