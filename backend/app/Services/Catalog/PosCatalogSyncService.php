<?php

namespace App\Services\Catalog;

use App\Models\Catalog;
use App\Models\Category;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\Store;
use App\Models\StoreProduct;
use App\Models\Warehouse;
use App\Services\Catalog\StoreCatalogService;
use App\Services\Inventory\OpeningStockService;
use Illuminate\Support\Collection;

class PosCatalogSyncService
{
    public function __construct(
        private readonly OpeningStockService $openingStock,
    ) {}

    /**
     * Build the catalog payload for a POS store import/sync.
     * Each item includes CDN image URLs from the product gallery.
     *
     * @return list<array<string, mixed>>
     */
    public function productsForStore(Store $store): array
    {
        $catalogIds = $this->catalogIdsForStore($store);
        if ($catalogIds->isEmpty()) {
            return [];
        }

        $storeProducts = StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('is_available', true)
            ->with(['category:id,name', 'brand:id,name', 'unit:id,name,code,symbol'])
            ->get()
            ->keyBy('product_id');

        if ($storeProducts->isEmpty()) {
            return [];
        }

        $stockByProduct = $this->stockByProduct($store);

        return Product::query()
            ->whereIn('id', $storeProducts->keys())
            ->whereIn('catalog_id', $catalogIds)
            ->where('is_active', true)
            ->with([
                'category:id,name',
                'images' => fn ($query) => $query->ordered(),
                'tax',
                'unitModel',
                'prices',
                'variants.prices',
                'variants.barcodes',
                'saleUnits',
                'bundleItems',
                'accompanimentProducts:id,sku,name,accompaniment_enabled,is_active',
                'barcodes',
                'batches:id,product_id,expires_at',
            ])
            ->orderBy('name')
            ->get()
            ->map(function (Product $product) use ($store, $storeProducts, $stockByProduct) {
                $storeProduct = $storeProducts->get($product->id);
                $payload = $storeProduct
                    ? $storeProduct->toPosSyncArray()
                    : $this->productPayload($product, $store);

                $payload['category_id'] = $storeProduct?->category_id ?: $product->category_id;
                $payload['category_name'] = $storeProduct?->category?->name ?? $product->category?->name;
                $payload['low_stock_threshold'] = $product->effectiveLowStockThreshold();
                $payload['cost_price'] = (int) ($product->cost_price ?? 0);
                $payload['track_expiration'] = $product->tracksExpiration();
                $earliestExpiry = $product->batches->pluck('expires_at')->filter()->sort()->values()->first();
                $payload['expires_at'] = $earliestExpiry instanceof \DateTimeInterface
                    ? $earliestExpiry->format('Y-m-d')
                    : null;
                $payload['is_available'] = $storeProduct ? (bool) $storeProduct->is_available : true;
                $activeVariants = $product->variants->where('is_active', true)->values();
                $payload['variants'] = $activeVariants->isNotEmpty()
                    ? $activeVariants->map->toPosSyncArray($store)->values()->all()
                    : [];
                $payload['option_groups'] = $product->metadata['option_groups'] ?? [];
                $payload['accompaniment_enabled'] = (bool) $product->accompaniment_enabled;
                $payload['accompaniments'] = $product->accompanimentProducts
                    ->map(fn (Product $item) => [
                        'product_id' => $item->id,
                        'sku' => $item->sku,
                        'name' => $item->name,
                    ])
                    ->values()
                    ->all();
                $payload['bottle_volume_ml'] = $product->bottle_volume_ml;
                $payload['sale_units'] = $product->saleUnits
                    ->where('is_active', true)
                    ->map(fn ($unit) => $unit->toPosArray((int) $product->bottle_volume_ml))
                    ->values()
                    ->all();
                $baseUnit = $product->saleUnits->firstWhere('is_base', true);
                if ($baseUnit && (int) $baseUnit->price > 0) {
                    $payload['price'] = (int) $baseUnit->price;
                }
                if ((int) ($payload['price'] ?? 0) <= 0) {
                    $payload['price'] = (int) ($product->base_price ?? 0);
                }
                $payload['wholesale_price'] = $product->effectivePrice('wholesale', $store) ?: $payload['price'];

                $onHand = (int) ($stockByProduct[$product->id] ?? 0);
                $payload['quantity_on_hand'] = $onHand;
                $payload['stock_display'] = $product->requiresStock()
                    ? $this->openingStock->describe($product, $onHand)['display']
                    : null;

                return $payload;
            })
            ->values()
            ->all();
    }

    public function ensureStoreProduct(Store $store, string $productId): ?StoreProduct
    {
        $existing = StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('product_id', $productId)
            ->first();

        if ($existing) {
            return $existing;
        }

        $product = Product::query()
            ->whereKey($productId)
            ->where('is_active', true)
            ->whereIn('catalog_id', $this->catalogIdsForStore($store))
            ->first();

        if (! $product) {
            return null;
        }

        return $product->importToStore($store);
    }

    /**
     * Categories for the POS: active catalog categories, plus any category
     * still referenced by a product so those products are not left uncategorized.
     *
     * @return list<array<string, mixed>>
     */
    public function categoriesForStore(Store $store): array
    {
        $catalogIds = $this->catalogIdsForStore($store);

        if ($catalogIds->isEmpty()) {
            return [];
        }

        $categories = Category::query()
            ->whereIn('catalog_id', $catalogIds)
            ->where(function ($query) use ($store) {
                $query->where('store_id', $store->id)->orWhereNull('store_id');
            })
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        $usedCategoryIds = Product::query()
            ->whereIn('catalog_id', $catalogIds)
            ->where('is_active', true)
            ->whereNotNull('category_id')
            ->whereHas('storeProducts', fn ($q) => $q->where('store_id', $store->id)->where('is_available', true))
            ->distinct()
            ->pluck('category_id')
            ->merge(
                StoreProduct::query()
                    ->where('store_id', $store->id)
                    ->where('is_available', true)
                    ->whereNotNull('category_id')
                    ->pluck('category_id')
            )
            ->unique()
            ->values();

        $byId = $categories->keyBy('id');
        $included = collect();

        $keep = function (string $id) use (&$keep, $byId, &$included): void {
            if ($included->has($id) || ! $byId->has($id)) {
                return;
            }

            $category = $byId->get($id);
            $included->put($id, $category);

            if ($category->parent_id) {
                $keep($category->parent_id);
            }
        };

        foreach ($categories as $category) {
            if ($category->is_active) {
                $keep($category->id);
            }
        }

        foreach ($usedCategoryIds as $categoryId) {
            $keep((string) $categoryId);
        }

        return $this->flattenCategoryTree($included->values());
    }

    /**
     * Barcode lookup index for POS offline scan.
     *
     * @return list<array<string, mixed>>
     */
    public function barcodesForStore(Store $store): array
    {
        return app(BarcodeService::class)->indexForStore($store);
    }

    /**
     *
     * @return list<array{product_id: string, images: list<array<string, mixed>>}>
     */
    public function imagesForStore(Store $store): array
    {
        return $this->importedProducts($store)
            ->map(fn (Product $product) => [
                'product_id' => $product->id,
                'primary_image_cdn_url' => $product->primaryImage()?->cdn_url,
                'images' => $product->images->map->toPosSyncArray()->values()->all(),
            ])
            ->values()
            ->all();
    }

    /**
     * @return Collection<int, string>
     */
    /** @return array<string, int> */
    private function stockByProduct(Store $store): array
    {
        $warehouseIds = Warehouse::query()
            ->where('branch_id', $store->branch_id)
            ->where('is_active', true)
            ->pluck('id');

        if ($warehouseIds->isEmpty()) {
            return [];
        }

        return StockBalance::query()
            ->whereIn('warehouse_id', $warehouseIds)
            ->selectRaw('product_id, SUM(quantity_on_hand) as qty')
            ->groupBy('product_id')
            ->pluck('qty', 'product_id')
            ->map(fn ($qty) => (int) $qty)
            ->all();
    }

    private function catalogIdsForStore(Store $store): Collection
    {
        $store->loadMissing('branch');
        $companyId = $store->branch?->company_id;
        if (! $companyId) {
            return collect();
        }

        app(StoreCatalogService::class)->bootstrap($store);

        return Catalog::query()
            ->where('company_id', $companyId)
            ->where('is_active', true)
            ->pluck('id');
    }

    /**
     * @return array<string, mixed>
     */
    private function productPayload(Product $product, Store $store): array
    {
        $primaryImage = $product->primaryImage();

        return [
            'store_product_id' => null,
            'store_id' => $store->id,
            'product_id' => $product->id,
            'category_id' => $product->category_id,
            'category_name' => $product->category?->name,
            'sku' => $product->sku,
            'name' => $product->name,
            'description' => $product->description,
            'barcode' => $product->primaryBarcode()?->barcode ?? $product->barcode,
            'barcodes' => $product->barcodes->map(fn ($barcode) => [
                'barcode' => $barcode->barcode,
                'type' => $barcode->type,
                'is_primary' => $barcode->is_primary,
            ])->values()->all(),
            'unit' => $product->unitModel?->code ?? $product->unit,
            'product_type' => $product->product_type,
            'requires_stock' => $product->requiresStock(),
            'is_weighable' => $product->isWeighable(),
            'is_serialized' => $product->is_serialized,
            'track_batch' => $product->track_batch,
            'track_expiration' => $product->track_expiration,
            'tax_rate' => $product->tax?->rate,
            'price' => $product->effectivePrice('retail', $store),
            'prices' => [],
            'default_price_type' => 'retail',
            'is_available' => true,
            'primary_image_cdn_url' => $primaryImage?->cdn_url,
            'images' => $product->imageGalleryForPos(),
            'variants' => [],
            'bundle_items' => $product->isBundle()
                ? $product->bundleItems->map(fn ($item) => [
                    'component_product_id' => $item->component_product_id,
                    'component_variant_id' => $item->component_variant_id,
                    'quantity' => (float) $item->quantity,
                ])->all()
                : [],
        ];
    }

    /**
     * @param  Collection<int, Category>  $categories
     * @return list<array<string, mixed>>
     */
    private function flattenCategoryTree(Collection $categories): array
    {
        $byParent = $categories->groupBy(fn (Category $category) => $category->parent_id ?? '');
        $flat = [];

        $walk = function (?string $parentId, int $depth) use (&$walk, $byParent, &$flat): void {
            foreach ($byParent->get($parentId ?? '', collect()) as $category) {
                $flat[] = [
                    'id' => $category->id,
                    'name' => $category->name,
                    'parent_id' => $category->parent_id,
                    'sort_order' => $category->sort_order,
                    'depth' => $depth,
                ];
                $walk($category->id, $depth + 1);
            }
        };

        $walk(null, 0);

        $listed = collect($flat)->pluck('id');
        foreach ($categories as $category) {
            if ($listed->contains($category->id)) {
                continue;
            }

            $flat[] = [
                'id' => $category->id,
                'name' => $category->name,
                'parent_id' => $category->parent_id,
                'sort_order' => $category->sort_order,
                'depth' => 0,
            ];
        }

        return $flat;
    }

    /**
     * @return Collection<int, Product>
     */
    private function importedProducts(Store $store): Collection
    {
        return Product::query()
            ->whereHas('storeProducts', fn ($query) => $query
                ->where('store_id', $store->id)
                ->where('is_available', true))
            ->with(['images' => fn ($query) => $query->ordered()])
            ->get();
    }
}
