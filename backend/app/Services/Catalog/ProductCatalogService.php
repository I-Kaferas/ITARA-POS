<?php

namespace App\Services\Catalog;

use App\Models\Catalog;
use App\Models\Product;
use App\Models\ProductBundleItem;
use App\Models\ProductVariant;
use App\Services\Audit\AuditLogService;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProductCatalogService
{
    public function __construct(
        private BarcodeService $barcodes,
        private PriceService $prices,
        private AuditLogService $audit,
        private ProductAccompanimentService $accompaniments,
    ) {}

    /** @param  array<string, mixed>  $data */
    public function create(Catalog $catalog, array $data): Product
    {
        return DB::transaction(function () use ($catalog, $data) {
            $product = $catalog->products()->create($this->productAttributes($data, $catalog));

            $this->syncRelations($product, $data);

            return $product->fresh($this->defaultRelations());
        });
    }

    /** @param  array<string, mixed>  $data */
    public function update(Product $product, array $data): Product
    {
        return DB::transaction(function () use ($product, $data) {
            $previousPrice = (int) $product->base_price;
            $product->update($this->productAttributes($data, $product->catalog, $product));
            if (! isset($data['prices']) && array_key_exists('base_price', $data)) {
                $this->audit->priceChanged($product, $previousPrice, (int) $product->base_price);
            }

            $this->syncRelations($product, $data);
            $this->accompaniments->detachDisabledAccompaniment($product);

            return $product->fresh($this->defaultRelations());
        });
    }

    /** @return list<string> */
    public function defaultRelations(): array
    {
        return [
            'category',
            'brand',
            'unitModel',
            'tax',
            'images',
            'variants.barcodes',
            'variants.prices',
            'bundleItems.componentProduct',
            'bundleItems.componentVariant',
            'accompanimentProducts:id,sku,name,accompaniment_enabled,is_active,base_price',
            'barcodes',
            'prices',
            'saleUnits',
        ];
    }

    /** @param  array<string, mixed>  $data */
    private function productAttributes(array $data, Catalog $catalog, ?Product $existing = null): array
    {
        $productType = $data['product_type'] ?? $existing?->product_type ?? 'simple';

        $this->validateProductType($productType, $data);

        $stockable = ! in_array($productType, Product::nonStockableTypes(), true);

        return [
            'tenant_id' => app('tenant.id'),
            'product_type' => $productType,
            'brand_id' => $data['brand_id'] ?? $existing?->brand_id,
            'unit_id' => $data['unit_id'] ?? $existing?->unit_id,
            'tax_id' => $data['tax_id'] ?? $existing?->tax_id,
            'sku' => $data['sku'] ?? $existing?->sku,
            'name' => $data['name'] ?? $existing?->name,
            'description' => array_key_exists('description', $data) ? $data['description'] : $existing?->description,
            'barcode' => $data['barcode'] ?? $existing?->barcode,
            'unit' => $data['unit'] ?? $existing?->unit ?? 'piece',
            'base_price' => $data['base_price'] ?? $existing?->base_price ?? 0,
            'cost_price' => $data['cost_price'] ?? $existing?->cost_price ?? 0,
            'category_id' => array_key_exists('category_id', $data) ? $data['category_id'] : $existing?->category_id,
            'is_active' => $data['is_active'] ?? $existing?->is_active ?? true,
            'is_serialized' => $stockable && ($data['is_serialized'] ?? $existing?->is_serialized ?? false),
            'track_batch' => $stockable && ($data['track_batch'] ?? ($productType === 'batch' || ($existing?->track_batch ?? false))),
            'track_expiration' => $stockable && ($data['track_expiration'] ?? $existing?->track_expiration ?? false),
            'expiration_days' => $stockable
                ? (array_key_exists('expiration_days', $data) ? $data['expiration_days'] : $existing?->expiration_days)
                : null,
            'low_stock_threshold' => array_key_exists('low_stock_threshold', $data) ? $data['low_stock_threshold'] : $existing?->low_stock_threshold,
            'metadata' => $data['metadata'] ?? $existing?->metadata,
            'accompaniment_enabled' => array_key_exists('accompaniment_enabled', $data)
                ? (bool) $data['accompaniment_enabled']
                : ($existing?->accompaniment_enabled ?? false),
        ];
    }

    /** @param  array<string, mixed>  $data */
    private function syncRelations(Product $product, array $data): void
    {
        if (isset($data['barcodes'])) {
            $this->barcodes->syncForModel($product, $data['barcodes']);
        } elseif (isset($data['barcode']) && $data['barcode']) {
            $this->barcodes->syncForModel($product, [
                ['barcode' => $data['barcode'], 'type' => 'internal', 'is_primary' => true],
            ]);
        }

        if (isset($data['prices'])) {
            $this->prices->syncForModel($product, $data['prices']);
        }

        if ($product->isVariantProduct() && isset($data['variants'])) {
            $this->syncVariants($product, $data['variants']);
        }

        if ($product->isBundle() && isset($data['bundle_items'])) {
            $this->syncBundleItems($product, $data['bundle_items']);
        }
    }

    /** @param  list<array<string, mixed>>  $variants */
    private function syncVariants(Product $product, array $variants): void
    {
        $keptIds = [];

        foreach ($variants as $index => $variantData) {
            $variant = isset($variantData['id'])
                ? ProductVariant::query()->where('product_id', $product->id)->findOrFail($variantData['id'])
                : new ProductVariant(['product_id' => $product->id, 'tenant_id' => $product->tenant_id]);

            $existed = $variant->exists;
            $previousPrice = (int) $variant->base_price;
            $variant->fill([
                'sku' => $variantData['sku'],
                'name' => $variantData['name'] ?? null,
                'size' => $variantData['size'] ?? null,
                'color' => $variantData['color'] ?? null,
                'color_hex' => $variantData['color_hex'] ?? null,
                'base_price' => $variantData['base_price'] ?? 0,
                'cost_price' => $variantData['cost_price'] ?? 0,
                'sort_order' => $variantData['sort_order'] ?? $index,
                'is_active' => $variantData['is_active'] ?? true,
                'attributes' => $variantData['attributes'] ?? null,
            ]);
            $variant->save();
            if ($existed && $previousPrice !== (int) $variant->base_price) {
                $this->audit->priceChanged($variant, $previousPrice, (int) $variant->base_price);
            }
            $keptIds[] = $variant->id;

            if (isset($variantData['barcodes'])) {
                $this->barcodes->syncForModel($variant, $variantData['barcodes']);
            }

            if (isset($variantData['prices'])) {
                $this->prices->syncForModel($variant, $variantData['prices']);
            }
        }

        ProductVariant::query()
            ->where('product_id', $product->id)
            ->whereNotIn('id', $keptIds)
            ->delete();
    }

    /** @param  list<array<string, mixed>>  $items */
    private function syncBundleItems(Product $product, array $items): void
    {
        ProductBundleItem::query()->where('bundle_product_id', $product->id)->delete();

        foreach ($items as $index => $item) {
            ProductBundleItem::query()->create([
                'tenant_id' => $product->tenant_id,
                'bundle_product_id' => $product->id,
                'component_product_id' => $item['component_product_id'],
                'component_variant_id' => $item['component_variant_id'] ?? null,
                'quantity' => $item['quantity'] ?? 1,
                'sort_order' => $item['sort_order'] ?? $index,
            ]);
        }
    }

    /** @param  array<string, mixed>  $data */
    private function validateProductType(string $type, array $data): void
    {
        if (! in_array($type, Product::productTypes(), true)) {
            throw ValidationException::withMessages([
                'product_type' => ['Type de produit invalide.'],
            ]);
        }

        if ($type === 'variant' && isset($data['variants']) && $data['variants'] === []) {
            throw ValidationException::withMessages([
                'variants' => ['Au moins une variante est requise.'],
            ]);
        }

        if ($type === 'bundle' && isset($data['bundle_items']) && $data['bundle_items'] === []) {
            throw ValidationException::withMessages([
                'bundle_items' => ['Au moins un composant est requis pour un bundle.'],
            ]);
        }
    }
}
