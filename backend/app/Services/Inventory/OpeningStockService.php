<?php

namespace App\Services\Inventory;

use App\Models\Product;
use App\Models\ProductSaleUnit;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class OpeningStockService
{
    /**
     * @return array{id: ?string, name: string, volume_ml: ?int}
     */
    public function resolveUnit(Product $product, ?string $saleUnitId): array
    {
        $unit = $this->findUnit($product, $saleUnitId);
        if ($unit) {
            return [
                'id' => $unit->id,
                'name' => $unit->name,
                'volume_ml' => (int) $unit->volume_ml,
            ];
        }

        $product->loadMissing('unitModel');

        return [
            'id' => null,
            'name' => $product->unitModel?->symbol
                ?: $product->unitModel?->name
                ?: ($product->unit ?: 'unité'),
            'volume_ml' => null,
        ];
    }

    /**
     * Convert an entered quantity into the stock base unit.
     * Volume products are stored in millilitres.
     *
     * @return array{
     *     sale_unit_id: ?string,
     *     entered_quantity: int,
     *     base_quantity: int,
     *     unit_name: string,
     *     unit_volume_ml: ?int,
     *     unit_cost: int,
     *     line_value: int,
     *     base_unit_cost: int
     * }
     */
    public function resolveLine(Product $product, int $quantity, ?string $saleUnitId, int $unitCost): array
    {
        $quantity = max(0, $quantity);
        $unit = $this->resolveUnit($product, $saleUnitId);
        $volume = $this->tracksVolume($product) ? max(1, (int) ($unit['volume_ml'] ?? 1)) : null;
        $baseQuantity = $volume ? $quantity * $volume : $quantity;
        $cost = $this->lineCost($product, $unitCost, $volume);
        $baseUnitCost = $volume ? intdiv($cost, $volume) : $cost;

        return [
            'sale_unit_id' => $unit['id'],
            'entered_quantity' => $quantity,
            'base_quantity' => $baseQuantity,
            'unit_name' => $unit['name'],
            'unit_volume_ml' => $volume,
            'unit_cost' => $cost,
            'line_value' => $quantity * $cost,
            'base_unit_cost' => $baseUnitCost,
        ];
    }

    /**
     * @return array{display: string, base_unit: string}
     */
    public function describe(Product $product, int $baseQuantity): array
    {
        $baseQuantity = max(0, $baseQuantity);
        if (! $this->tracksVolume($product)) {
            $unit = $this->resolveUnit($product, null);

            return [
                'display' => trim($baseQuantity.' '.$unit['name']),
                'base_unit' => $unit['name'],
            ];
        }

        $bottle = max(1, (int) $product->bottle_volume_ml);
        $bottles = intdiv($baseQuantity, $bottle);
        $remainder = $baseQuantity % $bottle;
        $baseName = $this->resolveUnit($product, null)['name'];
        $parts = [];
        if ($bottles > 0) {
            $parts[] = $bottles.' '.$baseName;
        }
        if ($remainder > 0 || $parts === []) {
            $parts[] = $remainder.' ml';
        }

        return [
            'display' => implode(' + ', $parts),
            'base_unit' => 'ml',
        ];
    }

    private function tracksVolume(Product $product): bool
    {
        return (int) $product->bottle_volume_ml > 0 && $this->units($product)->isNotEmpty();
    }

    private function findUnit(Product $product, ?string $saleUnitId): ?ProductSaleUnit
    {
        $units = $this->units($product);
        if ($units->isEmpty()) {
            return null;
        }

        if ($saleUnitId) {
            $match = $units->firstWhere('id', $saleUnitId);
            if (! $match instanceof ProductSaleUnit) {
                throw ValidationException::withMessages([
                    'sale_unit_id' => ['Cette unité de vente n’appartient pas à l’article.'],
                ]);
            }

            return $match;
        }

        $base = $units->firstWhere('is_base', true);

        return $base instanceof ProductSaleUnit ? $base : $units->first();
    }

    private static ?bool $saleUnitsTableExists = null;

    private function units(Product $product): Collection
    {
        self::$saleUnitsTableExists ??= Schema::hasTable('product_sale_units');
        if (! self::$saleUnitsTableExists) {
            return collect();
        }

        $product->loadMissing('saleUnits');

        return $product->saleUnits;
    }

    private function lineCost(Product $product, int $unitCost, ?int $volumeMl): int
    {
        if ($unitCost > 0) {
            return $unitCost;
        }

        $cost = max(0, (int) $product->cost_price);
        if ($volumeMl === null) {
            return $cost;
        }

        $bottle = max(1, (int) $product->bottle_volume_ml);

        return intdiv($cost * $volumeMl, $bottle);
    }
}
