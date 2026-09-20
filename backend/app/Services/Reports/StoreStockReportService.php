<?php

namespace App\Services\Reports;

use App\Enums\InventoryCountStatus;
use App\Enums\InventoryMovementType;
use App\Enums\SaleStatus;
use App\Models\GoodsReceipt;
use App\Models\InventoryCountItem;
use App\Models\InventoryMovement;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\StockBalance;
use App\Models\Store;
use App\Models\Warehouse;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class StoreStockReportService
{
    /** @return array<string, mixed> */
    public function summarize(?string $storeId, ?Carbon $from, ?Carbon $to, int $idleDays = 30): array
    {
        $from = ($from ?? now()->startOfMonth())->copy()->startOfDay();
        $to = ($to ?? now())->copy()->endOfDay();
        $idleDays = max(1, $idleDays);

        $store = $storeId ? Store::query()->with(['branch', 'users.roles'])->find($storeId) : null;
        $warehouseIds = $this->warehouseIdsForStore($store);

        $rows = $this->buildStockRows($warehouseIds, $from, $to);
        $movements = $this->periodMovements($warehouseIds, $from, $to);
        $sales = $this->salesPerformance($store?->id, $from, $to);
        $alerts = $this->buildAlerts($rows, $warehouseIds, $from, $to);
        $comparison = $this->storeComparison($from, $to);

        $openingValue = (int) $rows->sum('opening_value');
        $closingValue = (int) $rows->sum('closing_value');
        $variation = $closingValue - $openingValue;
        $variationPct = $openingValue > 0
            ? round(($variation / $openingValue) * 100, 1)
            : ($closingValue > 0 ? 100.0 : 0.0);

        $avgStockValue = max(1, (int) round(($openingValue + $closingValue) / 2));
        $cogs = (int) ($sales['cogs'] ?? 0);
        $turnoverRate = round($cogs / $avgStockValue, 2);

        $recommendations = $this->recommendations($rows, $comparison['transfer_opportunities'] ?? []);

        return [
            'generated_at' => now()->toIso8601String(),
            'period' => [
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
            ],
            'store' => $this->storeHeader($store),
            'summary' => [
                'opening_value' => $openingValue,
                'closing_value' => $closingValue,
                'variation_value' => $variation,
                'variation_pct' => $variationPct,
                'skus_in_stock' => $rows->where('closing_qty', '>', 0)->count(),
                'references_count' => $rows->count(),
                'stockouts' => $rows->where('status', 'out')->count(),
                'low_stock_count' => $rows->where('status', 'low')->count(),
                'overstock_count' => $rows->where('status', 'over')->count(),
                'healthy_count' => $rows->where('status', 'healthy')->count(),
                'turnover_rate' => $turnoverRate,
            ],
            'stock_health' => [
                ['label' => 'healthy', 'count' => $rows->where('status', 'healthy')->count()],
                ['label' => 'low', 'count' => $rows->where('status', 'low')->count()],
                ['label' => 'out', 'count' => $rows->where('status', 'out')->count()],
                ['label' => 'over', 'count' => $rows->where('status', 'over')->count()],
            ],
            'by_category' => $this->groupByCategory($rows),
            'stock_rows' => $rows->values()->all(),
            'movements' => $movements,
            'alerts' => $alerts,
            'performance' => [
                'top_sold' => $sales['top_sold'],
                'least_sold' => $sales['least_sold'],
                'no_movement' => $this->idleProducts($rows, $idleDays),
                'idle_days' => $idleDays,
                'service_rate' => $sales['service_rate'],
            ],
            'comparison' => $comparison,
            'recommendations' => $recommendations,
        ];
    }

    /**
     * @return list<string>
     */
    public function warehouseIdsForStore(?Store $store): array
    {
        $query = Warehouse::query()->where('is_active', true);
        if ($store) {
            $query->where('branch_id', $store->branch_id);
        }

        return $query->pluck('id')->all();
    }

    /** @return array<string, mixed> */
    private function storeHeader(?Store $store): array
    {
        if (! $store) {
            return [
                'id' => null,
                'name' => null,
                'code' => null,
                'kind' => null,
                'address' => null,
                'manager' => null,
            ];
        }

        $manager = $store->users
            ->first(fn ($user) => $user->roles->contains(fn ($role) => $role->slug === 'store_manager'))
            ?? $store->users->first();

        return [
            'id' => $store->id,
            'name' => $store->name,
            'code' => $store->code,
            'kind' => $store->kind,
            'address' => $this->formatAddress($store->branch?->address),
            'manager' => $manager?->name,
        ];
    }

    private function formatAddress(mixed $address): ?string
    {
        if (is_string($address) && trim($address) !== '') {
            return $address;
        }
        if (! is_array($address)) {
            return null;
        }

        $parts = array_filter([
            trim(implode(' ', array_filter([
                $address['number'] ?? null,
                $address['street'] ?? $address['line1'] ?? $address['avenue'] ?? null,
            ]))),
            $address['quarter'] ?? null,
            $address['commune'] ?? null,
            $address['city'] ?? null,
            $address['province'] ?? $address['state'] ?? null,
            $address['postal_code'] ?? null,
            $address['country'] ?? null,
        ], fn ($part) => is_string($part) && trim($part) !== '');

        return $parts === [] ? null : implode(', ', $parts);
    }

    /**
     * @param  list<string>  $warehouseIds
     * @return Collection<int, array<string, mixed>>
     */
    private function buildStockRows(array $warehouseIds, Carbon $from, Carbon $to): Collection
    {
        if ($warehouseIds === [] || ! Schema::hasTable('stock_balances')) {
            return collect();
        }

        $defaultThreshold = (int) config('inventory.default_low_stock_threshold', 10);
        $balances = StockBalance::query()
            ->with([
                'product:id,sku,name,cost_price,low_stock_threshold,category_id,unit_id,unit',
                'product.category:id,name',
                'product.unitModel:id,name,symbol,code',
            ])
            ->whereIn('warehouse_id', $warehouseIds)
            ->get()
            ->groupBy('product_id');

        $periodQty = $this->signedQtyByProduct($warehouseIds, $from, $to);
        $afterToQty = $this->signedQtyByProduct($warehouseIds, $to->copy()->addSecond(), now()->addDay());
        $inbound = $this->typedQtyByProduct($warehouseIds, $from, $to, inbound: true);
        $outbound = $this->typedQtyByProduct($warehouseIds, $from, $to, inbound: false);
        $lastMoved = $this->lastMovedAt($warehouseIds);

        $rows = collect();
        foreach ($balances as $productId => $group) {
            $first = $group->first();
            $product = $first?->product;
            $nowQty = (int) $group->sum('quantity_on_hand');
            $closingQty = $nowQty - (int) ($afterToQty[$productId] ?? 0);
            $openingQty = $closingQty - (int) ($periodQty[$productId] ?? 0);
            $threshold = (int) ($product?->low_stock_threshold ?? $defaultThreshold);
            if ($threshold <= 0) {
                $threshold = $defaultThreshold;
            }
            $maxStock = max($threshold * 3, $threshold + 50);
            $unitCost = (int) ($product?->cost_price ?? 0);
            $status = $this->status($closingQty, $threshold, $maxStock);
            $unit = $product?->unitModel?->symbol
                ?: $product?->unitModel?->name
                ?: $product?->unit
                ?: 'pcs';

            $rows->push([
                'product_id' => $productId,
                'sku' => $product?->sku,
                'name' => $product?->name,
                'category' => $product?->category?->name ?: '—',
                'unit' => $unit,
                'opening_qty' => $openingQty,
                'inbound_qty' => (int) ($inbound[$productId] ?? 0),
                'outbound_qty' => (int) ($outbound[$productId] ?? 0),
                'closing_qty' => $closingQty,
                'min_stock' => $threshold,
                'max_stock' => $maxStock,
                'unit_cost' => $unitCost,
                'opening_value' => $openingQty * $unitCost,
                'closing_value' => $closingQty * $unitCost,
                'status' => $status,
                'last_moved_at' => $lastMoved[$productId] ?? null,
            ]);
        }

        return $rows->sortBy('name', SORT_NATURAL | SORT_FLAG_CASE)->values();
    }

    /**
     * @param  list<string>  $warehouseIds
     * @return array<string, int>
     */
    private function signedQtyByProduct(array $warehouseIds, Carbon $from, Carbon $to): array
    {
        if (! Schema::hasTable('inventory_movements') || $warehouseIds === []) {
            return [];
        }

        return InventoryMovement::query()
            ->select('product_id', DB::raw('SUM(quantity) as qty'))
            ->whereIn('warehouse_id', $warehouseIds)
            ->where('occurred_at', '>=', $from)
            ->where('occurred_at', '<=', $to)
            ->groupBy('product_id')
            ->pluck('qty', 'product_id')
            ->map(fn ($qty) => (int) $qty)
            ->all();
    }

    /**
     * @param  list<string>  $warehouseIds
     * @return array<string, int>
     */
    private function typedQtyByProduct(array $warehouseIds, Carbon $from, Carbon $to, bool $inbound): array
    {
        if (! Schema::hasTable('inventory_movements') || $warehouseIds === []) {
            return [];
        }

        $types = $inbound
            ? ['PURCHASE', 'SALE_RETURN', 'TRANSFER_IN', 'ADJUSTMENT_IN', 'INITIAL_STOCK']
            : ['SALE', 'PURCHASE_RETURN', 'TRANSFER_OUT', 'ADJUSTMENT_OUT', 'DAMAGE', 'LOSS', 'EXPIRED'];

        return InventoryMovement::query()
            ->select('product_id', DB::raw('SUM(ABS(quantity)) as qty'))
            ->whereIn('warehouse_id', $warehouseIds)
            ->whereIn('movement_type', $types)
            ->where('occurred_at', '>=', $from)
            ->where('occurred_at', '<=', $to)
            ->groupBy('product_id')
            ->pluck('qty', 'product_id')
            ->map(fn ($qty) => (int) $qty)
            ->all();
    }

    /**
     * @param  list<string>  $warehouseIds
     * @return array<string, string>
     */
    private function lastMovedAt(array $warehouseIds): array
    {
        if (! Schema::hasTable('inventory_movements') || $warehouseIds === []) {
            return [];
        }

        return InventoryMovement::query()
            ->select('product_id', DB::raw('MAX(occurred_at) as last_at'))
            ->whereIn('warehouse_id', $warehouseIds)
            ->groupBy('product_id')
            ->pluck('last_at', 'product_id')
            ->all();
    }

    private function status(int $qty, int $min, int $max): string
    {
        if ($qty <= 0) {
            return 'out';
        }
        if ($qty <= $min) {
            return 'low';
        }
        if ($qty > $max) {
            return 'over';
        }

        return 'healthy';
    }

    /**
     * @param  Collection<int, array<string, mixed>>  $rows
     * @return list<array<string, mixed>>
     */
    private function groupByCategory(Collection $rows): array
    {
        return $rows
            ->groupBy('category')
            ->map(fn (Collection $group, string $label) => [
                'label' => $label,
                'quantity' => (int) $group->sum('closing_qty'),
                'value' => (int) $group->sum('closing_value'),
                'items' => $group->values()->all(),
            ])
            ->sortByDesc('value')
            ->values()
            ->all();
    }

    /**
     * @param  list<string>  $warehouseIds
     * @return array<string, mixed>
     */
    private function periodMovements(array $warehouseIds, Carbon $from, Carbon $to): array
    {
        $empty = [
            'inbound' => [],
            'outbound' => [],
            'transfers' => [],
            'adjustments' => [],
        ];

        if (! Schema::hasTable('inventory_movements') || $warehouseIds === []) {
            return $empty;
        }

        $movements = InventoryMovement::query()
            ->with([
                'product:id,sku,name,cost_price',
                'warehouse:id,name,code',
                'sourceWarehouse:id,name,code',
                'destinationWarehouse:id,name,code',
                'reference',
            ])
            ->whereIn('warehouse_id', $warehouseIds)
            ->where('occurred_at', '>=', $from)
            ->where('occurred_at', '<=', $to)
            ->orderByDesc('occurred_at')
            ->limit(800)
            ->get();

        $inbound = [];
        $outbound = [];
        $transfers = [];
        $adjustments = [];

        foreach ($movements as $movement) {
            $type = $movement->movement_type instanceof InventoryMovementType
                ? $movement->movement_type
                : InventoryMovementType::tryFrom((string) $movement->movement_type);
            if (! $type) {
                continue;
            }

            $qty = abs((int) $movement->quantity);
            $unit = (int) ($movement->unit_cost ?: $movement->product?->cost_price ?: 0);
            $base = [
                'occurred_at' => $movement->occurred_at?->toIso8601String(),
                'sku' => $movement->product?->sku,
                'name' => $movement->product?->name,
                'quantity' => $qty,
                'unit_cost' => $unit,
                'value' => $qty * $unit,
                'type' => $type->value,
                'notes' => $movement->notes,
            ];

            if (in_array($type, [InventoryMovementType::TransferIn, InventoryMovementType::TransferOut], true)) {
                $transfers[] = [
                    ...$base,
                    'origin' => $movement->sourceWarehouse?->name ?: $movement->warehouse?->name,
                    'destination' => $movement->destinationWarehouse?->name,
                ];
                continue;
            }

            if (in_array($type, InventoryMovementType::adjustmentTypes(), true)) {
                $adjustments[] = $base;
                continue;
            }

            if ($type->isInbound()) {
                $inbound[] = [
                    ...$base,
                    'supplier' => $this->movementSupplier($movement),
                ];
            } else {
                $outbound[] = [
                    ...$base,
                    'reason' => $type->specCode(),
                ];
            }
        }

        return [
            'inbound' => array_slice($inbound, 0, 80),
            'outbound' => array_slice($outbound, 0, 80),
            'transfers' => array_slice($transfers, 0, 80),
            'adjustments' => array_slice($adjustments, 0, 80),
        ];
    }

    private function movementSupplier(InventoryMovement $movement): ?string
    {
        $reference = $movement->reference;
        if ($reference instanceof GoodsReceipt) {
            $reference->loadMissing('purchaseOrder.supplier:id,name');

            return $reference->purchaseOrder?->supplier?->name;
        }

        return null;
    }

    /**
     * @param  Collection<int, array<string, mixed>>  $rows
     * @param  list<string>  $warehouseIds
     * @return array<string, mixed>
     */
    private function buildAlerts(Collection $rows, array $warehouseIds, Carbon $from, Carbon $to): array
    {
        $mapRow = fn (array $row) => [
            'product_id' => $row['product_id'],
            'sku' => $row['sku'],
            'name' => $row['name'],
            'category' => $row['category'],
            'closing_qty' => $row['closing_qty'],
            'min_stock' => $row['min_stock'],
            'max_stock' => $row['max_stock'],
            'closing_value' => $row['closing_value'],
        ];

        return [
            'out_of_stock' => $rows->where('status', 'out')->values()->map($mapRow)->all(),
            'below_min' => $rows->where('status', 'low')->values()->map($mapRow)->all(),
            'overstock' => $rows->where('status', 'over')->values()->map($mapRow)->all(),
            'expiring' => $this->expiring($warehouseIds),
            'count_variances' => $this->countVariances($warehouseIds, $from, $to),
        ];
    }

    /**
     * @param  list<string>  $warehouseIds
     * @return list<array<string, mixed>>
     */
    private function expiring(array $warehouseIds): array
    {
        if ($warehouseIds === [] || ! Schema::hasTable('stock_balances') || ! Schema::hasTable('batches')) {
            return [];
        }

        return StockBalance::query()
            ->with(['product:id,sku,name', 'warehouse:id,name', 'batch:id,batch_number,expires_at'])
            ->whereIn('warehouse_id', $warehouseIds)
            ->where('quantity_on_hand', '>', 0)
            ->whereNotNull('batch_id')
            ->get()
            ->filter(fn (StockBalance $balance) => $balance->batch?->expires_at !== null)
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
                    'expired' => $daysLeft !== null && $daysLeft < 0,
                    'soon' => $daysLeft !== null && $daysLeft >= 0 && $daysLeft <= 30,
                ];
            })
            ->filter(fn (array $row) => ($row['expired'] ?? false) || ($row['soon'] ?? false))
            ->sortBy('days_left')
            ->take(40)
            ->values()
            ->all();
    }

    /**
     * @param  list<string>  $warehouseIds
     * @return list<array<string, mixed>>
     */
    private function countVariances(array $warehouseIds, Carbon $from, Carbon $to): array
    {
        if ($warehouseIds === [] || ! Schema::hasTable('inventory_count_items') || ! Schema::hasTable('inventory_counts')) {
            return [];
        }

        $statuses = [
            InventoryCountStatus::Completed->value,
            InventoryCountStatus::Approved->value,
            InventoryCountStatus::Confirmed->value,
        ];

        return InventoryCountItem::query()
            ->with(['product:id,sku,name', 'inventoryCount:id,warehouse_id,counted_at,count_number,status'])
            ->whereHas('inventoryCount', function ($query) use ($warehouseIds, $from, $to, $statuses) {
                $query->whereIn('warehouse_id', $warehouseIds)
                    ->whereIn('status', $statuses)
                    ->where(function ($inner) use ($from, $to) {
                        $inner->whereBetween('counted_at', [$from->toDateString(), $to->toDateString()])
                            ->orWhereBetween('completed_at', [$from, $to]);
                    });
            })
            ->get()
            ->map(function (InventoryCountItem $item) {
                $counted = (int) ($item->counted_quantity ?? 0);
                $system = (int) ($item->system_quantity ?? 0);
                $variance = $counted - $system;

                return [
                    'sku' => $item->product?->sku,
                    'name' => $item->product?->name,
                    'count_number' => $item->inventoryCount?->count_number,
                    'counted_at' => optional($item->inventoryCount?->counted_at)->toDateString(),
                    'system_qty' => $system,
                    'counted_qty' => $counted,
                    'variance' => $variance,
                    'reason' => $item->variance_reason,
                ];
            })
            ->filter(fn (array $row) => $row['variance'] !== 0)
            ->sortByDesc(fn (array $row) => abs($row['variance']))
            ->take(40)
            ->values()
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    private function salesPerformance(?string $storeId, Carbon $from, Carbon $to): array
    {
        $emptyRate = ['fulfilled' => 0, 'total' => 0, 'rate' => 0];
        if (! Schema::hasTable('sales')) {
            return ['top_sold' => [], 'least_sold' => [], 'service_rate' => $emptyRate, 'cogs' => 0];
        }

        $salesQuery = Sale::query()->whereBetween('created_at', [$from, $to]);
        if ($storeId) {
            $salesQuery->where('store_id', $storeId);
        }

        $total = (clone $salesQuery)->whereIn('status', [
            SaleStatus::Completed->value,
            SaleStatus::Voided->value,
            SaleStatus::Pending->value,
        ])->count();
        $fulfilled = (clone $salesQuery)->where('status', SaleStatus::Completed->value)->count();
        $rate = $total > 0 ? round(($fulfilled / $total) * 100, 1) : 0.0;

        $completedIds = (clone $salesQuery)
            ->where('status', SaleStatus::Completed->value)
            ->pluck('id');

        if ($completedIds->isEmpty() || ! Schema::hasTable('sale_items')) {
            return [
                'top_sold' => [],
                'least_sold' => [],
                'service_rate' => ['fulfilled' => $fulfilled, 'total' => $total, 'rate' => $rate],
                'cogs' => 0,
            ];
        }

        $items = SaleItem::query()
            ->whereIn('sale_id', $completedIds)
            ->with(['product:id,name,sku,cost_price,category_id', 'product.category:id,name'])
            ->get(['product_id', 'product_name', 'product_sku', 'quantity', 'line_total', 'is_accompaniment']);

        $grouped = $items
            ->filter(fn (SaleItem $item) => ! $item->is_accompaniment)
            ->groupBy(fn (SaleItem $item) => $item->product_id ?: $item->product_name)
            ->map(function (Collection $group) {
                $first = $group->first();
                $qty = (int) $group->sum('quantity');
                $revenue = (int) $group->sum('line_total');
                $cost = (int) $group->sum(fn (SaleItem $item) => ((int) ($item->product?->cost_price ?? 0)) * (int) $item->quantity);

                return [
                    'product_id' => $first?->product_id,
                    'sku' => $first?->product?->sku ?? $first?->product_sku,
                    'name' => $first?->product?->name ?? $first?->product_name,
                    'category' => $first?->product?->category?->name,
                    'quantity' => $qty,
                    'revenue' => $revenue,
                    'cogs' => $cost,
                ];
            });

        $ranked = $grouped->sortByDesc('quantity')->values();

        return [
            'top_sold' => $ranked->take(10)->all(),
            'least_sold' => $ranked->sortBy('quantity')->take(10)->values()->all(),
            'service_rate' => ['fulfilled' => $fulfilled, 'total' => $total, 'rate' => $rate],
            'cogs' => (int) $grouped->sum('cogs'),
        ];
    }

    /**
     * @param  Collection<int, array<string, mixed>>  $rows
     * @return list<array<string, mixed>>
     */
    private function idleProducts(Collection $rows, int $idleDays): array
    {
        $cutoff = now()->subDays($idleDays);

        return $rows
            ->filter(function (array $row) use ($cutoff) {
                if ((int) $row['closing_qty'] <= 0) {
                    return false;
                }
                $last = $row['last_moved_at'] ?? null;
                if (! $last) {
                    return true;
                }

                return Carbon::parse($last)->lt($cutoff);
            })
            ->map(fn (array $row) => [
                'product_id' => $row['product_id'],
                'sku' => $row['sku'],
                'name' => $row['name'],
                'category' => $row['category'],
                'closing_qty' => $row['closing_qty'],
                'closing_value' => $row['closing_value'],
                'last_moved_at' => $row['last_moved_at'],
            ])
            ->sortBy('last_moved_at')
            ->take(40)
            ->values()
            ->all();
    }

    /** @return array<string, mixed> */
    private function storeComparison(Carbon $from, Carbon $to): array
    {
        $stores = Store::query()->where('is_active', true)->orderBy('name')->get(['id', 'name', 'code', 'branch_id']);
        $warehouses = Warehouse::query()
            ->where('is_active', true)
            ->get(['id', 'branch_id', 'name']);
        $warehousesByBranch = $warehouses->groupBy('branch_id');

        $defaultThreshold = (int) config('inventory.default_low_stock_threshold', 10);
        $balances = Schema::hasTable('stock_balances')
            ? StockBalance::query()
                ->with(['product:id,cost_price,low_stock_threshold,sku,name,category_id', 'product.category:id,name'])
                ->whereIn('warehouse_id', $warehouses->pluck('id'))
                ->get()
            : collect();

        $soldByWarehouse = [];
        if (Schema::hasTable('inventory_movements')) {
            $soldByWarehouse = InventoryMovement::query()
                ->select('warehouse_id', 'product_id', DB::raw('SUM(ABS(quantity)) as sold_qty'))
                ->where('movement_type', 'SALE')
                ->where('occurred_at', '>=', $from)
                ->where('occurred_at', '<=', $to)
                ->groupBy('warehouse_id', 'product_id')
                ->get()
                ->groupBy('warehouse_id');
        }

        $storeRows = [];
        $stockByStoreProduct = [];

        foreach ($stores as $store) {
            $whIds = ($warehousesByBranch[$store->branch_id] ?? collect())->pluck('id');
            $storeBalances = $balances->whereIn('warehouse_id', $whIds);
            $value = 0;
            $stockouts = 0;
            $skus = 0;
            $soldQty = 0;
            $onHand = 0;

            foreach ($storeBalances->groupBy('product_id') as $productId => $group) {
                $qty = (int) $group->sum('quantity_on_hand');
                $product = $group->first()?->product;
                $cost = (int) ($product?->cost_price ?? 0);
                $threshold = (int) ($product?->low_stock_threshold ?? $defaultThreshold) ?: $defaultThreshold;
                $value += $qty * $cost;
                $onHand += $qty;
                $skus++;
                if ($qty <= 0) {
                    $stockouts++;
                }
                $stockByStoreProduct[$store->id][$productId] = [
                    'qty' => $qty,
                    'threshold' => $threshold,
                    'sku' => $product?->sku,
                    'name' => $product?->name,
                    'store_name' => $store->name,
                    'store_code' => $store->code,
                ];
            }

            foreach ($whIds as $whId) {
                $soldQty += (int) (($soldByWarehouse[$whId] ?? collect())->sum('sold_qty'));
            }

            $avg = max($onHand, 1);
            $storeRows[] = [
                'store_id' => $store->id,
                'store_name' => $store->name,
                'store_code' => $store->code,
                'closing_value' => $value,
                'skus_in_stock' => $skus,
                'stockouts' => $stockouts,
                'sold_qty' => $soldQty,
                'turnover_rate' => round($soldQty / $avg, 2),
            ];
        }

        $best = collect($storeRows)->sortByDesc('turnover_rate')->first();
        $opportunities = $this->transferOpportunities($stockByStoreProduct);

        return [
            'stores' => $storeRows,
            'best_turnover_store' => $best['store_name'] ?? null,
            'transfer_opportunities' => $opportunities,
        ];
    }

    /**
     * @param  array<string, array<string, array<string, mixed>>>  $stockByStoreProduct
     * @return list<array<string, mixed>>
     */
    private function transferOpportunities(array $stockByStoreProduct): array
    {
        $opportunities = [];
        $storeIds = array_keys($stockByStoreProduct);
        $productIds = [];
        foreach ($stockByStoreProduct as $products) {
            foreach (array_keys($products) as $productId) {
                $productIds[$productId] = true;
            }
        }

        foreach (array_keys($productIds) as $productId) {
            $surplus = null;
            $deficit = null;
            foreach ($storeIds as $storeId) {
                $row = $stockByStoreProduct[$storeId][$productId] ?? null;
                if (! $row) {
                    continue;
                }
                $extra = (int) $row['qty'] - ((int) $row['threshold'] * 3);
                $need = (int) $row['threshold'] - (int) $row['qty'];
                if ($extra > 0 && ($surplus === null || $extra > $surplus['extra'])) {
                    $surplus = [...$row, 'store_id' => $storeId, 'extra' => $extra];
                }
                if ($need > 0 && ($deficit === null || $need > $deficit['need'])) {
                    $deficit = [...$row, 'store_id' => $storeId, 'need' => $need];
                }
            }

            if ($surplus && $deficit && $surplus['store_id'] !== $deficit['store_id']) {
                $qty = min((int) $surplus['extra'], (int) $deficit['need']);
                if ($qty > 0) {
                    $opportunities[] = [
                        'sku' => $surplus['sku'],
                        'name' => $surplus['name'],
                        'from_store' => $surplus['store_name'],
                        'to_store' => $deficit['store_name'],
                        'quantity' => $qty,
                        'reason' => 'over_to_low',
                    ];
                }
            }
        }

        usort($opportunities, fn ($a, $b) => $b['quantity'] <=> $a['quantity']);

        return array_slice($opportunities, 0, 20);
    }

    /**
     * @param  Collection<int, array<string, mixed>>  $rows
     * @param  list<array<string, mixed>>  $transfers
     * @return array<string, mixed>
     */
    private function recommendations(Collection $rows, array $transfers): array
    {
        $reorder = $rows
            ->filter(fn (array $row) => in_array($row['status'], ['out', 'low'], true))
            ->map(fn (array $row) => [
                'sku' => $row['sku'],
                'name' => $row['name'],
                'status' => $row['status'],
                'closing_qty' => $row['closing_qty'],
                'min_stock' => $row['min_stock'],
                'suggested_qty' => max(0, (int) $row['min_stock'] * 2 - (int) $row['closing_qty']),
            ])
            ->sortBy(fn (array $row) => $row['status'] === 'out' ? 0 : 1)
            ->take(20)
            ->values()
            ->all();

        $thresholds = $rows
            ->filter(function (array $row) {
                $soldish = (int) $row['outbound_qty'];
                if ($row['status'] === 'over' && $soldish === 0) {
                    return true;
                }
                if ($row['status'] === 'out' && $soldish > 0) {
                    return true;
                }

                return false;
            })
            ->map(function (array $row) {
                $sold = (int) $row['outbound_qty'];
                $suggestedMin = $row['status'] === 'out'
                    ? max((int) $row['min_stock'] + 5, (int) ceil($sold * 0.3))
                    : max(1, (int) floor((int) $row['min_stock'] * 0.5));
                $suggestedMax = $row['status'] === 'over'
                    ? max($suggestedMin * 2, (int) floor((int) $row['max_stock'] * 0.7))
                    : max($suggestedMin * 3, (int) $row['max_stock']);

                return [
                    'sku' => $row['sku'],
                    'name' => $row['name'],
                    'current_min' => $row['min_stock'],
                    'current_max' => $row['max_stock'],
                    'suggested_min' => $suggestedMin,
                    'suggested_max' => $suggestedMax,
                    'reason' => $row['status'] === 'over' ? 'overstock' : 'stockout',
                ];
            })
            ->take(20)
            ->values()
            ->all();

        return [
            'reorder_urgent' => $reorder,
            'transfer' => $transfers,
            'threshold_adjustments' => $thresholds,
        ];
    }
}
