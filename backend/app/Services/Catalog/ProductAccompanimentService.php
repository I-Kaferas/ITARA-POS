<?php

namespace App\Services\Catalog;

use App\Models\Product;
use App\Models\ProductAccompanimentLink;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class ProductAccompanimentService
{
    /**
     * @return list<array<string, mixed>>
     */
    public function list(): array
    {
        $productIds = ProductAccompanimentLink::query()
            ->orderBy('sort_order')
            ->pluck('product_id')
            ->unique()
            ->values();

        if ($productIds->isEmpty()) {
            return [];
        }

        $products = Product::query()
            ->with(['accompanimentProducts:id,sku,name,accompaniment_enabled,is_active,base_price'])
            ->whereIn('id', $productIds)
            ->orderBy('name')
            ->get(['id', 'sku', 'name', 'is_active', 'base_price']);

        return $products->map(fn (Product $product) => $this->serializeHost($product))->all();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function candidates(?string $excludeProductId = null): array
    {
        $query = Product::query()
            ->where('accompaniment_enabled', true)
            ->where('is_active', true)
            ->orderBy('name');

        if ($excludeProductId) {
            $query->where('id', '!=', $excludeProductId);
        }

        return $query->get(['id', 'sku', 'name', 'base_price', 'accompaniment_enabled'])
            ->map(fn (Product $product) => $this->serializeProduct($product))
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    public function forProduct(Product $product): array
    {
        $product->load(['accompanimentProducts:id,sku,name,accompaniment_enabled,is_active,base_price']);

        return [
            'product' => $this->serializeProduct($product),
            'accompaniments' => $product->accompanimentProducts
                ->map(fn (Product $item) => $this->serializeProduct($item))
                ->values()
                ->all(),
            'candidates' => $this->candidates($product->id),
        ];
    }

    /**
     * @param  list<string>  $accompanimentProductIds
     * @return array<string, mixed>
     */
    public function sync(Product $product, array $accompanimentProductIds): array
    {
        $ids = collect($accompanimentProductIds)
            ->filter(fn ($id) => is_string($id) && $id !== '')
            ->unique()
            ->values();

        if ($ids->contains($product->id)) {
            throw ValidationException::withMessages([
                'accompaniment_product_ids' => ['Un produit ne peut pas s’accompagner lui-même.'],
            ]);
        }

        $enabled = Product::query()
            ->whereIn('id', $ids)
            ->where('accompaniment_enabled', true)
            ->pluck('id');

        if ($enabled->count() !== $ids->count()) {
            throw ValidationException::withMessages([
                'accompaniment_product_ids' => ['Seuls les articles marqués « peut être un accompagnement » peuvent être liés.'],
            ]);
        }

        ProductAccompanimentLink::query()->where('product_id', $product->id)->delete();

        foreach ($ids as $index => $accompanimentId) {
            ProductAccompanimentLink::query()->create([
                'tenant_id' => $product->tenant_id,
                'product_id' => $product->id,
                'accompaniment_product_id' => $accompanimentId,
                'sort_order' => $index,
            ]);
        }

        return $this->forProduct($product->fresh());
    }

    public function detachDisabledAccompaniment(Product $product): void
    {
        if ($product->accompaniment_enabled) {
            return;
        }

        ProductAccompanimentLink::query()
            ->where('accompaniment_product_id', $product->id)
            ->delete();
    }

    /**
     * @return array<string, mixed>
     */
    public function serializeHost(Product $product): array
    {
        return [
            'id' => $product->id,
            'product' => $this->serializeProduct($product),
            'accompaniments' => $product->accompanimentProducts
                ->map(fn (Product $item) => $this->serializeProduct($item))
                ->values()
                ->all(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function serializeProduct(Product $product): array
    {
        return [
            'id' => $product->id,
            'sku' => $product->sku,
            'name' => $product->name,
            'base_price' => (int) $product->base_price,
            'is_active' => (bool) ($product->is_active ?? true),
            'accompaniment_enabled' => (bool) $product->accompaniment_enabled,
        ];
    }

    /**
     * @param  Collection<int, Product>  $products
     * @return array<string, list<array<string, mixed>>>
     */
    public function mapForProducts(Collection $products): array
    {
        if ($products->isEmpty()) {
            return [];
        }

        $links = ProductAccompanimentLink::query()
            ->with('accompanimentProduct:id,sku,name,accompaniment_enabled,is_active,base_price')
            ->whereIn('product_id', $products->pluck('id'))
            ->orderBy('sort_order')
            ->get()
            ->groupBy('product_id');

        $mapped = [];
        foreach ($links as $productId => $rows) {
            $mapped[$productId] = $rows
                ->map(fn (ProductAccompanimentLink $link) => $link->accompanimentProduct
                    ? $this->serializeProduct($link->accompanimentProduct)
                    : null)
                ->filter()
                ->values()
                ->all();
        }

        return $mapped;
    }
}
