<?php

namespace App\Services\Desk;

use App\Enums\InventoryMovementType;
use App\Models\Catalog;
use App\Models\DeskDocument;
use App\Models\Product;
use App\Models\ProductBundleItem;
use App\Models\StockBalance;
use App\Models\Store;
use App\Models\Warehouse;
use App\Services\Inventory\InventoryMovementService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ProductionDesk
{
    public function __construct(private readonly InventoryMovementService $movements) {}

    /** @return array<string, mixed> */
    public function snapshot(Store $store): array
    {
        try {
            $this->ensureExample($store);
        } catch (\Throwable) {
            // Une recette d'exemple incomplète ne doit pas bloquer les recettes déjà en catalogue.
        }
        $products = Product::query()->with('bundleItems.componentProduct')->orderBy('name')->get();
        $stock = $this->stockMap($store);
        $recipes = $products
            ->filter(fn (Product $product) => $product->bundleItems->isNotEmpty())
            ->map(fn (Product $product) => $this->recipe($product, $stock))
            ->values()
            ->all();

        $runs = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'production_run')
            ->latest('created_at')
            ->limit(12)
            ->get()
            ->map(fn (DeskDocument $doc) => array_merge($doc->payload ?? [], ['id' => $doc->code]))
            ->values()
            ->all();

        return [
            'recipes' => $recipes,
            'runs' => $runs,
            'products' => $products->map(fn (Product $product) => [
                'id' => $product->id,
                'name' => $product->name,
                'quantity_on_hand' => $stock[$product->id] ?? 0,
            ])->values()->all(),
        ];
    }

    /** @param  array<string, mixed>  $action
     * @return array<string, mixed>
     */
    public function apply(Store $store, array $action, ?string $userId): array
    {
        if (($action['action'] ?? 'produce') !== 'produce') {
            throw ValidationException::withMessages(['action' => ['Action inconnue.']]);
        }

        $batches = (int) ($action['batches'] ?? 1);
        if ($batches < 1) {
            throw ValidationException::withMessages(['batches' => ['Quantité de production invalide.']]);
        }

        $product = Product::query()->with('bundleItems.componentProduct')->find($action['recipe_id'] ?? null);
        if ($product === null || $product->bundleItems->isEmpty()) {
            throw ValidationException::withMessages(['recipe_id' => ['Recette introuvable. Utilisez un produit pack avec des composants.']]);
        }

        $warehouse = $this->warehouse($store);
        $stock = $this->stockMap($store);
        $ingredients = [];
        foreach ($product->bundleItems as $item) {
            $quantity = (int) round(((float) $item->quantity) * $batches);
            if ($quantity < 1) {
                continue;
            }
            $onHand = $stock[$item->component_product_id] ?? 0;
            if ($onHand < $quantity) {
                throw ValidationException::withMessages([
                    'batches' => ['Stock insuffisant pour '.($item->componentProduct?->name ?? 'un composant').'.'],
                ]);
            }
            $ingredients[] = [
                'product' => $item->componentProduct,
                'product_id' => $item->component_product_id,
                'name' => $item->componentProduct?->name,
                'quantity' => $quantity,
            ];
        }

        $finishedQty = $batches;
        $runId = (string) Str::uuid();

        DB::transaction(function () use ($store, $warehouse, $product, $ingredients, $finishedQty, $batches, $userId, $runId) {
            foreach ($ingredients as $ingredient) {
                if ($ingredient['product'] === null) {
                    continue;
                }
                $this->movements->record([
                    'warehouse' => $warehouse,
                    'product' => $ingredient['product'],
                    'movement_type' => InventoryMovementType::AdjustmentOut,
                    'quantity' => $ingredient['quantity'],
                    'performed_by' => $userId,
                    'notes' => 'Production '.$product->name,
                ]);
            }
            $this->movements->record([
                'warehouse' => $warehouse,
                'product' => $product,
                'movement_type' => InventoryMovementType::AdjustmentIn,
                'quantity' => $finishedQty,
                'performed_by' => $userId,
                'notes' => 'Production '.$product->name,
            ]);
            DeskDocument::query()->create([
                'tenant_id' => $store->tenant_id,
                'store_id' => $store->id,
                'code' => $runId,
                'kind' => 'production_run',
                'status' => 'done',
                'payload' => [
                    'recipe_id' => $product->id,
                    'recipe_name' => $product->name,
                    'batches' => $batches,
                    'finished_quantity' => $finishedQty,
                    'ingredients' => collect($ingredients)->map(fn ($line) => [
                        'product_id' => $line['product_id'],
                        'name' => $line['name'],
                        'quantity' => $line['quantity'],
                    ])->all(),
                    'produced_at' => now()->toIso8601String(),
                ],
            ]);
        });

        return $this->snapshot($store);
    }

    /** @return array<string, int> */
    private function stockMap(Store $store): array
    {
        $warehouse = Warehouse::query()->where('branch_id', $store->branch_id)->where('is_active', true)->first();
        if ($warehouse === null) {
            return [];
        }

        return StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->get()
            ->groupBy('product_id')
            ->map(fn ($rows) => (int) $rows->sum('quantity_on_hand'))
            ->all();
    }

    /** @param  array<string, int>  $stock
     * @return array<string, mixed>
     */
    private function recipe(Product $product, array $stock): array
    {
        $lines = $product->bundleItems->map(fn ($item) => [
            'product_id' => $item->component_product_id,
            'name' => $item->componentProduct?->name ?? 'Composant',
            'quantity' => (float) $item->quantity,
            'on_hand' => $stock[$item->component_product_id] ?? 0,
        ])->values()->all();

        return [
            'id' => $product->id,
            'name' => $product->name,
            'finished_product_id' => $product->id,
            'finished_name' => $product->name,
            'yield_quantity' => 1,
            'on_hand' => $stock[$product->id] ?? 0,
            'lines' => $lines,
            'source' => 'catalog',
        ];
    }

    private function ensureExample(Store $store): void
    {
        $hasRecipe = Product::query()
            ->where('tenant_id', $store->tenant_id)
            ->whereHas('bundleItems')
            ->exists();
        if ($hasRecipe) {
            return;
        }

        $catalog = Catalog::query()
            ->where('tenant_id', $store->tenant_id)
            ->where('is_active', true)
            ->orderByDesc('is_default')
            ->first();
        if ($catalog === null) {
            return;
        }

        $ingredients = [];
        foreach (['FARINE' => 'Farine', 'FROMAGE' => 'Fromage', 'SAUCE' => 'Sauce', 'VIANDE' => 'Viande'] as $sku => $name) {
            $ingredients[] = Product::query()->firstOrCreate(
                ['tenant_id' => $store->tenant_id, 'sku' => $sku],
                [
                    'catalog_id' => $catalog->id,
                    'name' => $name,
                    'product_type' => 'simple',
                    'unit' => 'piece',
                    'base_price' => 0,
                    'is_active' => true,
                ],
            );
        }

        $pizza = Product::query()->firstOrCreate(
            ['tenant_id' => $store->tenant_id, 'sku' => 'PIZZA'],
            [
                'catalog_id' => $catalog->id,
                'name' => 'Pizza',
                'product_type' => 'simple',
                'unit' => 'piece',
                'base_price' => 0,
                'is_active' => true,
            ],
        );

        if ($pizza->bundleItems()->doesntExist()) {
            foreach ($ingredients as $index => $ingredient) {
                ProductBundleItem::query()->create([
                    'tenant_id' => $store->tenant_id,
                    'bundle_product_id' => $pizza->id,
                    'component_product_id' => $ingredient->id,
                    'quantity' => 1,
                    'sort_order' => $index + 1,
                ]);
            }
        }

        $warehouse = Warehouse::query()->where('branch_id', $store->branch_id)->where('is_active', true)->first();
        if ($warehouse === null) {
            return;
        }

        $stock = $this->stockMap($store);
        foreach ($ingredients as $ingredient) {
            if (($stock[$ingredient->id] ?? 0) > 0) {
                continue;
            }
            try {
                $this->movements->record([
                    'warehouse' => $warehouse,
                    'product' => $ingredient,
                    'movement_type' => InventoryMovementType::AdjustmentIn,
                    'quantity' => 20,
                    'notes' => 'Stock initial recette Pizza',
                ]);
            } catch (\Throwable) {
                // La recette reste visible. La production signalera le stock manquant.
            }
        }
    }

    private function warehouse(Store $store): Warehouse
    {
        $warehouse = Warehouse::query()->where('branch_id', $store->branch_id)->where('is_active', true)->first();
        if ($warehouse === null) {
            throw ValidationException::withMessages(['warehouse' => ['Aucun entrepôt pour ce magasin.']]);
        }

        return $warehouse;
    }
}
