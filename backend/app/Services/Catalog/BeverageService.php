<?php

namespace App\Services\Catalog;

use App\Enums\InventoryMovementType;
use App\Enums\SaleStatus;
use App\Models\Product;
use App\Models\ProductSaleUnit;
use App\Models\SaleItem;
use App\Models\StockBalance;
use App\Models\Warehouse;
use App\Services\Inventory\InventoryMovementService;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BeverageService
{
    public function __construct(
        private readonly InventoryMovementService $movements,
    ) {}

    /**
     * @param  list<array{name: string, volume_ml: int, price: int, is_base?: bool}>  $units
     */
    public function save(Product $product, int $bottleVolumeMl, int $costPrice, array $units): Product
    {
        if ($bottleVolumeMl < 1) {
            throw ValidationException::withMessages([
                'bottle_volume_ml' => ['Le volume de la bouteille est requis.'],
            ]);
        }

        if ($units === []) {
            throw ValidationException::withMessages([
                'units' => ['Ajoutez au moins une unité de vente.'],
            ]);
        }

        return DB::transaction(function () use ($product, $bottleVolumeMl, $costPrice, $units): Product {
            $normalized = $this->normalizeUnits($units, $bottleVolumeMl);
            $base = collect($normalized)->firstWhere('is_base', true) ?? $normalized[0];

            $product->update([
                'bottle_volume_ml' => $bottleVolumeMl,
                'cost_price' => max(0, $costPrice),
                'base_price' => $base['price'],
            ]);

            $product->saleUnits()->delete();

            foreach ($normalized as $index => $unit) {
                $product->saleUnits()->create([
                    'tenant_id' => $product->tenant_id,
                    'name' => $unit['name'],
                    'code' => $unit['code'],
                    'volume_ml' => $unit['volume_ml'],
                    'price' => $unit['price'],
                    'is_base' => $unit['is_base'],
                    'sort_order' => $index,
                    'is_active' => true,
                ]);
            }

            return $product->fresh(['saleUnits', 'brand']);
        });
    }

    public function removeUnit(Product $product, ProductSaleUnit $unit): void
    {
        if ($unit->product_id !== $product->id) {
            throw ValidationException::withMessages([
                'unit' => ['Cette unité n’appartient pas à cette boisson.'],
            ]);
        }

        if ($product->saleUnits()->count() <= 1) {
            throw ValidationException::withMessages([
                'unit' => ['Conservez au moins une unité de vente.'],
            ]);
        }

        DB::transaction(function () use ($product, $unit): void {
            $wasBase = $unit->is_base;
            $unit->delete();

            if ($wasBase) {
                $next = $product->saleUnits()->orderBy('sort_order')->first();
                $next?->update(['is_base' => true]);
                if ($next) {
                    $product->update(['base_price' => $next->price]);
                }
            }
        });
    }

    public function setStock(Product $product, Warehouse $warehouse, int $bottles, ?string $userId = null): void
    {
        $volume = (int) $product->bottle_volume_ml;
        if ($volume < 1) {
            throw ValidationException::withMessages([
                'bottle_volume_ml' => ['Configurez d’abord le volume de la bouteille.'],
            ]);
        }

        $targetMl = max(0, $bottles) * $volume;
        $onHand = (int) StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->whereNull('product_variant_id')
            ->whereNull('batch_id')
            ->sum('quantity_on_hand');

        $delta = $targetMl - $onHand;
        if ($delta === 0) {
            return;
        }

        $this->movements->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => $delta > 0
                ? ($onHand === 0 ? InventoryMovementType::InitialStock : InventoryMovementType::AdjustmentIn)
                : InventoryMovementType::AdjustmentOut,
            'quantity' => abs($delta),
            'unit_cost' => $this->costPerMl($product),
            'performed_by' => $userId,
            'notes' => 'Stock boisson en millilitres',
        ]);
    }

    /** @return array<string, int|string> */
    public function splitStock(int $ml, int $bottleVolumeMl): array
    {
        $volume = max(1, $bottleVolumeMl);

        return [
            'ml' => max(0, $ml),
            'bottles' => intdiv(max(0, $ml), $volume),
            'remainder_ml' => max(0, $ml) % $volume,
        ];
    }

    public function costPerMl(Product $product): int
    {
        $volume = (int) $product->bottle_volume_ml;

        return $volume > 0 ? intdiv((int) $product->cost_price, $volume) : 0;
    }

    public function lineCost(Product $product, int $volumeMl): int
    {
        $volume = (int) $product->bottle_volume_ml;
        if ($volume < 1 || $volumeMl < 1) {
            return 0;
        }

        return intdiv((int) $product->cost_price * $volumeMl, $volume);
    }

    /**
     * @return array<string, mixed>
     */
    public function dashboard(?string $warehouseId = null): array
    {
        $products = Product::query()
            ->whereNotNull('bottle_volume_ml')
            ->where('bottle_volume_ml', '>', 0)
            ->with(['brand:id,name', 'saleUnits'])
            ->orderBy('name')
            ->get();

        $stockQuery = StockBalance::query()->whereIn('product_id', $products->pluck('id'));
        if ($warehouseId) {
            $stockQuery->where('warehouse_id', $warehouseId);
        }

        $onHand = $stockQuery
            ->selectRaw('product_id, SUM(quantity_on_hand) as ml')
            ->groupBy('product_id')
            ->pluck('ml', 'product_id');

        $todayItems = SaleItem::query()
            ->whereNotNull('volume_ml')
            ->whereHas('sale', fn ($query) => $query
                ->where('status', SaleStatus::Completed)
                ->whereDate('completed_at', today()))
            ->with('product:id,name,sku,cost_price,bottle_volume_ml')
            ->get();

        $revenue = (int) $todayItems->sum('line_total');
        $cost = $todayItems->sum(function (SaleItem $item): int {
            $product = $item->product;
            if ($product === null) {
                return 0;
            }

            return $this->lineCost($product, (int) $item->volume_ml);
        });

        $rows = $products->map(function (Product $product) use ($onHand): array {
            $ml = (int) ($onHand[$product->id] ?? 0);
            $split = $this->splitStock($ml, (int) $product->bottle_volume_ml);
            $dose = $product->saleUnits->first(fn (ProductSaleUnit $unit) => ! $unit->is_base)
                ?? $product->saleUnits->first();

            return [
                'id' => $product->id,
                'name' => $product->name,
                'sku' => $product->sku,
                'brand' => $product->brand?->name,
                'bottle_volume_ml' => $product->bottle_volume_ml,
                'cost_price' => $product->cost_price,
                'stock' => $split,
                'doses_available' => $dose && $dose->volume_ml > 0 ? intdiv($ml, $dose->volume_ml) : 0,
                'dose_name' => $dose?->name,
                'units' => $product->saleUnits->map(fn (ProductSaleUnit $unit) => [
                    ...$unit->toPosArray((int) $product->bottle_volume_ml),
                    'profit' => $unit->price - $this->lineCost($product, $unit->volume_ml),
                ])->values(),
            ];
        })->values();

        $top = $todayItems
            ->groupBy('product_id')
            ->map(function ($items) {
                $first = $items->first();

                return [
                    'product_id' => $first->product_id,
                    'name' => $first->product_name,
                    'quantity' => (int) $items->sum('quantity'),
                    'volume_ml' => (int) $items->sum('volume_ml'),
                    'revenue' => (int) $items->sum('line_total'),
                ];
            })
            ->sortByDesc('revenue')
            ->take(5)
            ->values();

        return [
            'products' => $rows,
            'today' => [
                'sales_count' => $todayItems->pluck('sale_id')->unique()->count(),
                'quantity' => (int) $todayItems->sum('quantity'),
                'volume_ml' => (int) $todayItems->sum('volume_ml'),
                'revenue' => $revenue,
                'cost' => $cost,
                'profit' => $revenue - $cost,
            ],
            'top_products' => $top,
        ];
    }

    /**
     * @param  list<array{name: string, volume_ml: int, price: int, is_base?: bool}>  $units
     * @return list<array{name: string, code: string, volume_ml: int, price: int, is_base: bool}>
     */
    private function normalizeUnits(array $units, int $bottleVolumeMl): array
    {
        $normalized = [];
        $baseIndex = null;

        foreach ($units as $unit) {
            $name = trim((string) ($unit['name'] ?? ''));
            $volume = (int) ($unit['volume_ml'] ?? 0);
            if ($name === '' || $volume < 1) {
                continue;
            }
            if ($volume > $bottleVolumeMl) {
                throw ValidationException::withMessages([
                    'units' => ["{$name} dépasse le volume de la bouteille."],
                ]);
            }

            $row = [
                'name' => $name,
                'code' => strtoupper(substr((string) preg_replace('/[^A-Za-z0-9]+/', '', $name), 0, 20)),
                'volume_ml' => $volume,
                'price' => max(0, (int) ($unit['price'] ?? 0)),
                'is_base' => (bool) ($unit['is_base'] ?? false) || $volume === $bottleVolumeMl,
            ];
            if ($row['is_base'] && $baseIndex === null) {
                $baseIndex = count($normalized);
            }
            $normalized[] = $row;
        }

        if ($normalized === []) {
            throw ValidationException::withMessages([
                'units' => ['Ajoutez au moins une unité de vente.'],
            ]);
        }

        if ($baseIndex === null) {
            $normalized[0]['is_base'] = true;
        } else {
            foreach ($normalized as $index => $unit) {
                $normalized[$index]['is_base'] = $index === $baseIndex;
            }
        }

        return $normalized;
    }
}
