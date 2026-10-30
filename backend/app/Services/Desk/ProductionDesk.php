<?php

namespace App\Services\Desk;

use App\Enums\InventoryMovementType;
use App\Models\DeskDocument;
use App\Models\Product;
use App\Models\ProductBundleItem;
use App\Models\StockBalance;
use App\Models\Store;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Inventory\InventoryMovementService;
use App\Services\Inventory\StoreStockLocation;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * A recipe is a stockable, non-bundle product with components: producing it
 * consumes the ingredients and adds the finished good to the store stock.
 * Bundles are excluded because a sale already consumes their components.
 */
class ProductionDesk
{
    private const MAX_BATCHES = 500;

    public function __construct(
        private readonly InventoryMovementService $movements,
        private readonly StoreStockLocation $locations,
    ) {}

    /** @return array<string, mixed> */
    public function snapshot(Store $store): array
    {
        $warehouse = $this->locations->forStore($store);
        $stock = $this->stockMap($warehouse);
        $storeProductIds = $this->storeProductIds($store);

        $products = Product::query()
            ->with(['bundleItems.componentProduct.unitModel', 'unitModel'])
            ->where('is_active', true)
            ->orderBy('name')
            ->get()
            ->filter(fn (Product $product) => $product->requiresStock() && ! $product->isBundle())
            ->values();

        $recipes = $products
            ->filter(fn (Product $product) => $product->bundleItems->isNotEmpty())
            ->map(fn (Product $product) => $this->recipe($product, $stock, $storeProductIds))
            ->values()
            ->all();

        $runs = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'production_run')
            ->latest('created_at')
            ->limit(30)
            ->get()
            ->map(fn (DeskDocument $doc) => $this->presentRun($doc))
            ->values()
            ->all();

        return [
            'warehouse' => ['id' => $warehouse->id, 'name' => $warehouse->name],
            'recipes' => $recipes,
            'runs' => $runs,
            'stats' => $this->stats($store),
            'products' => $products->map(fn (Product $product) => [
                'id' => $product->id,
                'name' => $product->name,
                'sku' => $product->sku,
                'unit' => $this->unitLabel($product),
                'cost_price' => (int) $product->cost_price,
                'quantity_on_hand' => $stock[$product->id] ?? 0,
                'in_store' => isset($storeProductIds[$product->id]),
                'is_recipe' => $product->bundleItems->isNotEmpty(),
            ])->values()->all(),
        ];
    }

    /** @param  array<string, mixed>  $action
     * @return array<string, mixed>
     */
    public function apply(Store $store, array $action, ?string $userId): array
    {
        match ($action['action'] ?? 'produce') {
            'produce' => $this->produce($store, $action, $userId),
            'save_recipe' => $this->saveRecipe($action),
            'delete_recipe' => $this->deleteRecipe($action),
            'reverse_run' => $this->reverseRun($store, $action, $userId),
            default => throw ValidationException::withMessages(['action' => ['Action inconnue.']]),
        };

        return $this->snapshot($store);
    }

    /** @param  array<string, mixed>  $action */
    private function produce(Store $store, array $action, ?string $userId): void
    {
        $batches = (int) ($action['batches'] ?? 1);
        if ($batches < 1 || $batches > self::MAX_BATCHES) {
            throw ValidationException::withMessages([
                'batches' => ['Indiquez un nombre de fournées entre 1 et '.self::MAX_BATCHES.'.'],
            ]);
        }

        $product = $this->recipeProduct((string) ($action['recipe_id'] ?? ''));
        $warehouse = $this->locations->forStore($store);
        $stock = $this->stockMap($warehouse);
        $yield = $this->yieldOf($product);
        $finishedQty = $yield * $batches;

        $ingredients = [];
        $missing = [];
        foreach ($product->bundleItems as $item) {
            $component = $item->componentProduct;
            if ($component === null || ! $component->requiresStock()) {
                continue;
            }
            $quantity = $this->consumption((float) $item->quantity, $batches);
            $onHand = $stock[$component->id] ?? 0;
            if ($onHand < $quantity) {
                $missing[] = "{$component->name} (besoin {$quantity}, en stock {$onHand})";
            }
            $unitCost = $this->unitCost($component);
            $ingredients[] = [
                'product' => $component,
                'product_id' => $component->id,
                'name' => $component->name,
                'unit' => $this->unitLabel($component),
                'quantity' => $quantity,
                'cost' => (int) round($unitCost * $quantity),
            ];
        }

        if ($missing !== []) {
            throw ValidationException::withMessages([
                'batches' => ['Stock insuffisant : '.implode(', ', $missing).'.'],
            ]);
        }

        $totalCost = array_sum(array_column($ingredients, 'cost'));
        $user = $userId ? User::query()->find($userId) : null;

        DB::transaction(function () use ($store, $warehouse, $product, $ingredients, $finishedQty, $batches, $yield, $userId, $user, $totalCost) {
            $run = DeskDocument::query()->create([
                'tenant_id' => $store->tenant_id,
                'store_id' => $store->id,
                'code' => (string) Str::uuid(),
                'kind' => 'production_run',
                'status' => 'done',
                'payload' => [
                    'recipe_id' => $product->id,
                    'recipe_name' => $product->name,
                    'unit' => $this->unitLabel($product),
                    'batches' => $batches,
                    'yield_quantity' => $yield,
                    'finished_quantity' => $finishedQty,
                    'total_cost' => $totalCost,
                    'unit_cost' => $finishedQty > 0 ? (int) round($totalCost / $finishedQty) : 0,
                    'ingredients' => collect($ingredients)->map(fn ($line) => [
                        'product_id' => $line['product_id'],
                        'name' => $line['name'],
                        'unit' => $line['unit'],
                        'quantity' => $line['quantity'],
                        'cost' => $line['cost'],
                    ])->all(),
                    'performed_by' => $userId,
                    'performed_by_name' => $user?->name,
                    'produced_at' => now()->toIso8601String(),
                ],
            ]);

            foreach ($ingredients as $ingredient) {
                $this->movements->record([
                    'warehouse' => $warehouse,
                    'product' => $ingredient['product'],
                    'movement_type' => InventoryMovementType::AdjustmentOut,
                    'quantity' => $ingredient['quantity'],
                    'reference' => $run,
                    'performed_by' => $userId,
                    'notes' => 'Production '.$product->name,
                ]);
            }

            $this->movements->record([
                'warehouse' => $warehouse,
                'product' => $product,
                'movement_type' => InventoryMovementType::AdjustmentIn,
                'quantity' => $finishedQty,
                'unit_cost' => $finishedQty > 0 ? (int) round($totalCost / $finishedQty) : null,
                'reference' => $run,
                'performed_by' => $userId,
                'notes' => 'Production '.$product->name,
            ]);
        });
    }

    /** @param  array<string, mixed>  $action */
    private function reverseRun(Store $store, array $action, ?string $userId): void
    {
        $run = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'production_run')
            ->where('code', (string) ($action['run_id'] ?? ''))
            ->first();
        if ($run === null) {
            throw ValidationException::withMessages(['run_id' => ['Fabrication introuvable.']]);
        }
        if ($run->status === 'reversed') {
            throw ValidationException::withMessages(['run_id' => ['Cette fabrication est déjà annulée.']]);
        }

        $payload = $run->payload ?? [];
        $finished = Product::query()->find($payload['recipe_id'] ?? null);
        if ($finished === null) {
            throw ValidationException::withMessages(['run_id' => ['Le produit fini n\'existe plus.']]);
        }

        $warehouse = $this->locations->forStore($store);
        $finishedQty = (int) ($payload['finished_quantity'] ?? 0);
        $onHand = $this->stockMap($warehouse)[$finished->id] ?? 0;
        if ($onHand < $finishedQty) {
            throw ValidationException::withMessages([
                'run_id' => ["Impossible d'annuler : {$finished->name} n'a plus que {$onHand} en stock sur {$finishedQty} produits."],
            ]);
        }

        $user = $userId ? User::query()->find($userId) : null;

        DB::transaction(function () use ($run, $payload, $finished, $finishedQty, $warehouse, $userId, $user) {
            if ($finishedQty > 0) {
                $this->movements->record([
                    'warehouse' => $warehouse,
                    'product' => $finished,
                    'movement_type' => InventoryMovementType::AdjustmentOut,
                    'quantity' => $finishedQty,
                    'reference' => $run,
                    'performed_by' => $userId,
                    'notes' => 'Annulation production '.$finished->name,
                ]);
            }

            foreach ($payload['ingredients'] ?? [] as $line) {
                $ingredient = Product::query()->find($line['product_id'] ?? null);
                $quantity = (int) ($line['quantity'] ?? 0);
                if ($ingredient === null || $quantity < 1 || ! $ingredient->requiresStock()) {
                    continue;
                }
                $this->movements->record([
                    'warehouse' => $warehouse,
                    'product' => $ingredient,
                    'movement_type' => InventoryMovementType::AdjustmentIn,
                    'quantity' => $quantity,
                    'unit_cost' => $quantity > 0 ? (int) round(((int) ($line['cost'] ?? 0)) / $quantity) : null,
                    'reference' => $run,
                    'performed_by' => $userId,
                    'notes' => 'Annulation production '.$finished->name,
                ]);
            }

            $run->status = 'reversed';
            $run->payload = array_merge($payload, [
                'reversed_at' => now()->toIso8601String(),
                'reversed_by_name' => $user?->name,
            ]);
            $run->save();
        });
    }

    /** @param  array<string, mixed>  $action */
    private function saveRecipe(array $action): void
    {
        $product = Product::query()->find((string) ($action['product_id'] ?? ''));
        if ($product === null) {
            throw ValidationException::withMessages(['product_id' => ['Choisissez le produit fini.']]);
        }
        if ($product->isBundle() || ! $product->requiresStock()) {
            throw ValidationException::withMessages([
                'product_id' => ['Le produit fini doit être un article stocké (pas un pack ni un service).'],
            ]);
        }

        $yield = (int) ($action['yield_quantity'] ?? 1);
        if ($yield < 1) {
            throw ValidationException::withMessages(['yield_quantity' => ['Le rendement doit être d\'au moins 1.']]);
        }

        $lines = collect($action['lines'] ?? [])
            ->filter(fn ($line) => is_array($line) && ! empty($line['product_id']))
            ->map(fn ($line) => [
                'product_id' => (string) $line['product_id'],
                'quantity' => (float) ($line['quantity'] ?? 0),
            ])
            ->values();

        if ($lines->isEmpty()) {
            throw ValidationException::withMessages(['lines' => ['Ajoutez au moins un ingrédient.']]);
        }
        if ($lines->pluck('product_id')->duplicates()->isNotEmpty()) {
            throw ValidationException::withMessages(['lines' => ['Un ingrédient apparaît deux fois.']]);
        }
        if ($lines->contains(fn ($line) => $line['product_id'] === $product->id)) {
            throw ValidationException::withMessages(['lines' => ['Le produit fini ne peut pas être son propre ingrédient.']]);
        }
        if ($lines->contains(fn ($line) => $line['quantity'] <= 0)) {
            throw ValidationException::withMessages(['lines' => ['Chaque ingrédient doit avoir une quantité positive.']]);
        }

        $ingredients = Product::query()->whereIn('id', $lines->pluck('product_id'))->get()->keyBy('id');
        foreach ($lines as $line) {
            $ingredient = $ingredients->get($line['product_id']);
            if ($ingredient === null) {
                throw ValidationException::withMessages(['lines' => ['Ingrédient introuvable.']]);
            }
            if ($ingredient->isBundle() || ! $ingredient->requiresStock()) {
                throw ValidationException::withMessages([
                    'lines' => ["{$ingredient->name} ne peut pas être un ingrédient (pack ou service)."],
                ]);
            }
        }

        DB::transaction(function () use ($product, $lines, $yield) {
            $product->bundleItems()->delete();
            foreach ($lines as $index => $line) {
                ProductBundleItem::query()->create([
                    'tenant_id' => $product->tenant_id,
                    'bundle_product_id' => $product->id,
                    'component_product_id' => $line['product_id'],
                    'quantity' => $line['quantity'],
                    'sort_order' => $index + 1,
                ]);
            }
            $product->metadata = array_merge($product->metadata ?? [], ['recipe_yield' => $yield]);
            $product->save();
        });
    }

    /** @param  array<string, mixed>  $action */
    private function deleteRecipe(array $action): void
    {
        $product = $this->recipeProduct((string) ($action['recipe_id'] ?? ''));

        DB::transaction(function () use ($product) {
            $product->bundleItems()->delete();
            $metadata = $product->metadata ?? [];
            unset($metadata['recipe_yield']);
            $product->metadata = $metadata;
            $product->save();
        });
    }

    private function recipeProduct(string $id): Product
    {
        $product = $id === '' ? null : Product::query()->with('bundleItems.componentProduct.unitModel')->find($id);
        if ($product === null || $product->isBundle() || $product->bundleItems->isEmpty()) {
            throw ValidationException::withMessages(['recipe_id' => ['Recette introuvable.']]);
        }

        return $product;
    }

    /** @return array<string, int> */
    private function stockMap(Warehouse $warehouse): array
    {
        return StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->get(['product_id', 'quantity_on_hand'])
            ->groupBy('product_id')
            ->map(fn ($rows) => (int) $rows->sum('quantity_on_hand'))
            ->all();
    }

    /** @return array<string, true> */
    private function storeProductIds(Store $store): array
    {
        return DB::table('store_products')
            ->where('store_id', $store->id)
            ->pluck('product_id')
            ->mapWithKeys(fn ($id) => [(string) $id => true])
            ->all();
    }

    /**
     * @param  array<string, int>  $stock
     * @param  array<string, true>  $storeProductIds
     * @return array<string, mixed>
     */
    private function recipe(Product $product, array $stock, array $storeProductIds): array
    {
        $lines = $product->bundleItems
            ->filter(fn ($item) => $item->componentProduct !== null)
            ->map(function ($item) use ($stock) {
                $component = $item->componentProduct;
                $perBatch = (float) $item->quantity;
                $onHand = $stock[$component->id] ?? 0;

                return [
                    'product_id' => $component->id,
                    'name' => $component->name,
                    'unit' => $this->unitLabel($component),
                    'quantity' => $perBatch,
                    'on_hand' => $onHand,
                    'unit_cost' => round($this->unitCost($component), 2),
                    'batch_cost' => (int) round($this->unitCost($component) * $perBatch),
                    'max_batches' => $component->requiresStock()
                        ? $this->maxBatches($perBatch, $onHand)
                        : null,
                ];
            })
            ->values();

        $yield = $this->yieldOf($product);
        $batchCost = (int) $lines->sum('batch_cost');
        $capacities = $lines->pluck('max_batches')->filter(fn ($value) => $value !== null);
        $maxBatches = $capacities->isEmpty() ? 0 : (int) $capacities->min();

        return [
            'id' => $product->id,
            'name' => $product->name,
            'sku' => $product->sku,
            'unit' => $this->unitLabel($product),
            'yield_quantity' => $yield,
            'on_hand' => $stock[$product->id] ?? 0,
            'price' => (int) $product->base_price,
            'batch_cost' => $batchCost,
            'unit_cost' => (int) round($batchCost / max(1, $yield)),
            'max_batches' => $maxBatches,
            'in_store' => isset($storeProductIds[$product->id]),
            'lines' => $lines->all(),
        ];
    }

    /** @return array<string, mixed> */
    private function presentRun(DeskDocument $doc): array
    {
        $payload = $doc->payload ?? [];

        return array_merge($payload, [
            'id' => $doc->code,
            'status' => $doc->status ?? 'done',
            'produced_at' => $payload['produced_at'] ?? $doc->created_at?->toIso8601String(),
            'ingredients' => array_values($payload['ingredients'] ?? []),
        ]);
    }

    /** @return array<string, int> */
    private function stats(Store $store): array
    {
        /** @var Collection<int, DeskDocument> $today */
        $today = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'production_run')
            ->where('status', 'done')
            ->where('created_at', '>=', now()->startOfDay())
            ->get();

        return [
            'runs_today' => $today->count(),
            'units_today' => (int) $today->sum(fn (DeskDocument $doc) => (int) ($doc->payload['finished_quantity'] ?? 0)),
            'cost_today' => (int) $today->sum(fn (DeskDocument $doc) => (int) ($doc->payload['total_cost'] ?? 0)),
        ];
    }

    private function yieldOf(Product $product): int
    {
        return max(1, (int) ($product->metadata['recipe_yield'] ?? 1));
    }

    private function consumption(float $perBatch, int $batches): int
    {
        return max(1, (int) round($perBatch * $batches));
    }

    private function maxBatches(float $perBatch, int $onHand): int
    {
        if ($perBatch <= 0 || $onHand <= 0) {
            return 0;
        }

        $batches = (int) floor($onHand / $perBatch);
        while ($batches > 0 && $this->consumption($perBatch, $batches) > $onHand) {
            $batches--;
        }

        return min($batches, self::MAX_BATCHES);
    }

    /** Cost of one stock unit (ml for volume products), in cents. */
    private function unitCost(Product $product): float
    {
        $cost = (float) $product->cost_price;
        $volume = (int) $product->bottle_volume_ml;

        return $volume > 0 && $product->tracksVolume() ? $cost / $volume : $cost;
    }

    private function unitLabel(Product $product): string
    {
        if ((int) $product->bottle_volume_ml > 0 && $product->tracksVolume()) {
            return 'ml';
        }

        $symbol = $product->unitModel?->symbol;
        if (is_string($symbol) && $symbol !== '') {
            return $symbol;
        }
        $code = strtolower(trim((string) $product->unit));

        return match ($code) {
            '', 'piece', 'pieces', 'pcs', 'unit', 'unite', 'unité' => 'pc',
            'litre', 'liter', 'l' => 'L',
            default => (string) $product->unit,
        };
    }
}
