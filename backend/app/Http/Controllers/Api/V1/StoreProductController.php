<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CatalogAttribute;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreProduct;
use App\Services\Audit\AuditLogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class StoreProductController extends Controller
{
    public function index(Store $store): JsonResponse
    {
        $items = StoreProduct::query()
            ->where('store_id', $store->id)
            ->with(['product.images', 'category', 'brand', 'unit'])
            ->get()
            ->map(fn (StoreProduct $sp) => $this->serialize($sp));

        return response()->json(['data' => $items]);
    }

    public function import(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'product_ids' => ['required', 'array', 'min:1'],
            'product_ids.*' => ['uuid', 'exists:products,id'],
            ...$this->taxonomyRules($store),
        ]);

        $taxonomy = $this->taxonomyFrom($data, $store);
        $imported = [];

        foreach ($data['product_ids'] as $productId) {
            $product = Product::query()->findOrFail($productId);
            $imported[] = $product->importToStore(
                $store,
                importedBy: $request->user()?->id,
                taxonomy: $taxonomy,
            );
        }

        return response()->json([
            'data' => $this->serializedByIds(collect($imported)->pluck('id')->all()),
        ], 201);
    }

    public function classify(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'product_ids' => ['required', 'array', 'min:1'],
            'product_ids.*' => ['uuid'],
            ...$this->taxonomyRules($store, sometimes: true),
        ]);

        $updates = [];
        foreach (['category_id', 'brand_id', 'unit_id'] as $key) {
            if ($request->exists($key)) {
                $updates[$key] = $data[$key] ?? null;
            }
        }
        if ($request->exists('attributes')) {
            $updates['attributes'] = $this->normalizeAttributes($store, $data['attributes'] ?? []);
        }

        if ($updates === []) {
            throw ValidationException::withMessages([
                'product_ids' => ['Choisissez au moins une catégorie, marque, unité ou attribut.'],
            ]);
        }

        $items = StoreProduct::query()
            ->where('store_id', $store->id)
            ->whereIn('product_id', $data['product_ids'])
            ->get();

        foreach ($items as $item) {
            $item->update($updates);
        }

        return response()->json([
            'data' => $this->serializedByIds($items->pluck('id')->all()),
        ]);
    }

    public function update(Request $request, Store $store, Product $product): JsonResponse
    {
        $data = $request->validate([
            'is_available' => ['boolean'],
            'price_override' => ['nullable', 'integer', 'min:0'],
            ...$this->taxonomyRules($store),
        ]);

        $storeProduct = StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('product_id', $product->id)
            ->firstOrFail();

        $previous = $storeProduct->price_override;
        if (array_key_exists('attributes', $data)) {
            $data['attributes'] = $this->normalizeAttributes($store, $data['attributes'] ?? []);
        }
        $storeProduct->update($data);
        if (array_key_exists('price_override', $data) && (int) $previous !== (int) ($data['price_override'] ?? 0)) {
            app(AuditLogService::class)->priceChanged(
                $product,
                (int) ($previous ?? $product->base_price),
                (int) ($data['price_override'] ?? $product->base_price),
                $request,
            );
        }

        return response()->json([
            'data' => $this->serialize($storeProduct->fresh()->load(['product.images', 'category', 'brand', 'unit'])),
        ]);
    }

    public function destroy(Store $store, Product $product): JsonResponse
    {
        StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('product_id', $product->id)
            ->delete();

        return response()->json(['message' => 'Removed from store.']);
    }

    /**
     * @return array<string, list<mixed>>
     */
    private function taxonomyRules(Store $store, bool $sometimes = false): array
    {
        $presence = $sometimes ? ['sometimes', 'nullable'] : ['nullable'];

        return [
            'category_id' => [
                ...$presence,
                'uuid',
                Rule::exists('categories', 'id')->where(fn ($query) => $query->where('store_id', $store->id)),
            ],
            'brand_id' => [
                ...$presence,
                'uuid',
                Rule::exists('brands', 'id')->where(fn ($query) => $query->where('store_id', $store->id)),
            ],
            'unit_id' => [
                ...$presence,
                'uuid',
                Rule::exists('units', 'id')->where(fn ($query) => $query->where('store_id', $store->id)),
            ],
            'attributes' => [...($sometimes ? ['sometimes'] : []), 'nullable', 'array'],
            'attributes.*.attribute_id' => [
                'required',
                'uuid',
                Rule::exists('catalog_attributes', 'id')->where(fn ($query) => $query->where('store_id', $store->id)),
            ],
            'attributes.*.value' => ['required', 'string', 'max:120'],
        ];
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array{category_id: ?string, brand_id: ?string, unit_id: ?string, attributes: list<array<string, mixed>>}
     */
    private function taxonomyFrom(array $data, Store $store): array
    {
        return [
            'category_id' => $data['category_id'] ?? null,
            'brand_id' => $data['brand_id'] ?? null,
            'unit_id' => $data['unit_id'] ?? null,
            'attributes' => $this->normalizeAttributes($store, $data['attributes'] ?? []),
        ];
    }

    /**
     * @param  list<array<string, mixed>>|null  $attributes
     * @return list<array{attribute_id: string, name: string, code: string, value: string}>
     */
    private function normalizeAttributes(Store $store, ?array $attributes): array
    {
        if (! $attributes) {
            return [];
        }

        $ids = collect($attributes)->pluck('attribute_id')->filter()->unique()->values();
        $definitions = CatalogAttribute::query()
            ->where('store_id', $store->id)
            ->whereIn('id', $ids)
            ->get()
            ->keyBy('id');

        $normalized = [];

        foreach ($attributes as $row) {
            $definition = $definitions->get((string) ($row['attribute_id'] ?? ''));
            $value = trim((string) ($row['value'] ?? ''));
            if (! $definition || $value === '') {
                continue;
            }

            $allowed = array_map('strval', $definition->values ?? []);
            if (! in_array($value, $allowed, true)) {
                throw ValidationException::withMessages([
                    'attributes' => ["La valeur « {$value} » n'appartient pas à l'attribut {$definition->name}."],
                ]);
            }

            $normalized[] = [
                'attribute_id' => $definition->id,
                'name' => $definition->name,
                'code' => $definition->code,
                'value' => $value,
            ];
        }

        return $normalized;
    }

    /**
     * @param  list<string>  $ids
     * @return list<array<string, mixed>>
     */
    private function serializedByIds(array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        return StoreProduct::query()
            ->whereIn('id', $ids)
            ->with(['product.images', 'category', 'brand', 'unit'])
            ->get()
            ->map(fn (StoreProduct $sp) => $this->serialize($sp))
            ->values()
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    private function serialize(StoreProduct $sp): array
    {
        return [
            'id' => $sp->id,
            'product_id' => $sp->product_id,
            'is_available' => $sp->is_available,
            'price_override' => $sp->price_override,
            'effective_price' => $sp->effectivePrice(),
            'imported_at' => $sp->imported_at,
            'category_id' => $sp->category_id,
            'brand_id' => $sp->brand_id,
            'unit_id' => $sp->unit_id,
            'attributes' => $sp->attributes ?? [],
            'category' => $sp->category,
            'brand' => $sp->brand,
            'unit' => $sp->unit,
            'product' => $sp->product,
        ];
    }
}
