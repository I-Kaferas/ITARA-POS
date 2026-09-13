<?php

namespace App\Services\Inventory;

use App\Enums\InventoryMovementType;
use App\Models\InventoryMovement;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\Warehouse;

class StockLedgerService
{
    public function __construct(
        private readonly OpeningStockService $openingStock,
    ) {}

    /**
     * Ledger by product for one warehouse.
     *
     * calculated = opening + purchases + entries + adjustments_in - sales - losses - adjustments_out
     *
     * @return list<array<string, mixed>>
     */
    public function summarize(Warehouse $warehouse, ?string $productId = null): array
    {
        $movementQuery = InventoryMovement::query()->where('warehouse_id', $warehouse->id);
        $balanceQuery = StockBalance::query()->where('warehouse_id', $warehouse->id);

        if ($productId) {
            $movementQuery->where('product_id', $productId);
            $balanceQuery->where('product_id', $productId);
        }

        $movements = $movementQuery->get(['product_id', 'movement_type', 'quantity', 'unit_cost']);
        $balances = $balanceQuery->get(['product_id', 'quantity_on_hand', 'quantity_reserved']);

        $productIds = $movements->pluck('product_id')
            ->merge($balances->pluck('product_id'))
            ->unique()
            ->filter()
            ->values();

        if ($productIds->isEmpty()) {
            return [];
        }

        $products = Product::query()
            ->with(['category:id,name', 'saleUnits', 'unitModel'])
            ->whereIn('id', $productIds)
            ->get()
            ->keyBy('id');

        $onHand = $balances->groupBy('product_id')->map(
            fn ($rows) => (int) $rows->sum('quantity_on_hand'),
        );
        $buckets = $movements->groupBy('product_id');
        $rows = [];

        foreach ($productIds as $id) {
            $product = $products->get($id);
            if (! $product instanceof Product) {
                continue;
            }

            $totals = $this->emptyTotals();
            $costNumerator = 0;
            $costDenominator = 0;

            foreach ($buckets->get($id, []) as $movement) {
                $type = $movement->movement_type instanceof InventoryMovementType
                    ? $movement->movement_type
                    : InventoryMovementType::parse((string) $movement->movement_type);
                $quantity = (int) $movement->quantity;
                $this->accumulate($totals, $type, $quantity);

                if ($quantity > 0 && (int) $movement->unit_cost > 0) {
                    $costNumerator += $quantity * (int) $movement->unit_cost;
                    $costDenominator += $quantity;
                }
            }

            $calculated = $totals['opening']
                + $totals['purchases']
                + $totals['entries']
                + $totals['adjustments_in']
                - $totals['sales']
                - $totals['losses']
                - $totals['adjustments_out'];

            $quantityOnHand = (int) ($onHand[$id] ?? $calculated);
            $averageCost = $costDenominator > 0
                ? intdiv($costNumerator, $costDenominator)
                : $this->fallbackUnitCost($product);
            $described = $this->openingStock->describe($product, abs($quantityOnHand));
            $threshold = $product->effectiveLowStockThreshold();

            $rows[] = [
                'product_id' => $product->id,
                'name' => $product->name,
                'sku' => $product->sku,
                'category' => $product->category?->name,
                'opening' => $totals['opening'],
                'purchases' => $totals['purchases'],
                'entries' => $totals['entries'],
                'sales' => $totals['sales'],
                'losses' => $totals['losses'],
                'adjustments_in' => $totals['adjustments_in'],
                'adjustments_out' => $totals['adjustments_out'],
                'calculated' => $calculated,
                'quantity_on_hand' => $quantityOnHand,
                'display' => ($quantityOnHand < 0 ? '-' : '').$described['display'],
                'base_unit' => $described['base_unit'],
                'average_cost' => $averageCost,
                'stock_value' => $quantityOnHand * $averageCost,
                'low_stock_threshold' => $threshold,
                'low_stock' => $threshold !== null && $quantityOnHand <= $threshold,
                'formula' => 'opening + purchases + entries + adjustments_in - sales - losses - adjustments_out',
            ];
        }

        usort($rows, fn (array $a, array $b): int => strcasecmp((string) $a['name'], (string) $b['name']));

        return $rows;
    }

    /**
     * @return array{
     *     opening: int,
     *     purchases: int,
     *     entries: int,
     *     sales: int,
     *     losses: int,
     *     adjustments_in: int,
     *     adjustments_out: int
     * }
     */
    private function emptyTotals(): array
    {
        return [
            'opening' => 0,
            'purchases' => 0,
            'entries' => 0,
            'sales' => 0,
            'losses' => 0,
            'adjustments_in' => 0,
            'adjustments_out' => 0,
        ];
    }

    /**
     * @param  array<string, int>  $totals
     */
    private function accumulate(array &$totals, InventoryMovementType $type, int $quantity): void
    {
        match ($type) {
            InventoryMovementType::InitialStock => $totals['opening'] += $quantity,
            InventoryMovementType::Purchase => $totals['purchases'] += $quantity,
            InventoryMovementType::TransferIn, InventoryMovementType::SaleReturn => $totals['entries'] += $quantity,
            InventoryMovementType::Sale => $totals['sales'] += abs($quantity),
            InventoryMovementType::Damage, InventoryMovementType::Loss, InventoryMovementType::Expired => $totals['losses'] += abs($quantity),
            InventoryMovementType::AdjustmentIn => $totals['adjustments_in'] += $quantity,
            InventoryMovementType::AdjustmentOut, InventoryMovementType::TransferOut, InventoryMovementType::PurchaseReturn => $totals['adjustments_out'] += abs($quantity),
        };
    }

    private function fallbackUnitCost(Product $product): int
    {
        $cost = max(0, (int) $product->cost_price);
        $bottle = (int) $product->bottle_volume_ml;

        return $bottle > 0 ? intdiv($cost, $bottle) : $cost;
    }
}
