<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\Tenant;
use App\Services\Catalog\ProductCatalogService;
use App\Services\Platform\SaasLimitGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;

class ProductController extends Controller
{
    public function __construct(private ProductCatalogService $catalog) {}

    public function index(Request $request, Catalog $catalog): JsonResponse
    {
        $query = $catalog->products()
            ->with($this->listWith($request))
            ->orderBy('name');

        if ($type = $request->string('product_type')->toString()) {
            $query->where('product_type', $type);
        }

        if ($request->boolean('stockable')) {
            $query->whereNotIn('product_type', Product::nonStockableTypes());
        }

        if ($brandId = $request->string('brand_id')->toString()) {
            $query->where('brand_id', $brandId);
        }

        if ($categoryId = $request->string('category_id')->toString()) {
            $query->where('category_id', $categoryId);
        }

        if ($search = $request->string('search')->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('sku', 'like', "%{$search}%")
                    ->orWhere('barcode', 'like', "%{$search}%")
                    ->orWhereHas('barcodes', fn ($bq) => $bq->where('barcode', 'like', "%{$search}%"))
                    ->orWhereHas('variants', fn ($vq) => $vq
                        ->where('sku', 'like', "%{$search}%")
                        ->orWhere('name', 'like', "%{$search}%"));
            });
        }

        if ($request->has('per_page') || $request->has('page')) {
            $page = $query->paginate($request->pageSize(40));
            $rows = $this->presentList($this->withStock(collect($page->items())), $request->boolean('compact'));

            return response()->json([
                'data' => $rows->values(),
                'meta' => [
                    'current_page' => $page->currentPage(),
                    'last_page' => $page->lastPage(),
                    'per_page' => $page->perPage(),
                    'total' => $page->total(),
                ],
            ]);
        }

        return response()->json([
            'data' => $this->presentList($this->withStock($query->get()), $request->boolean('compact'))->values(),
        ]);
    }

    public function store(Request $request, Catalog $catalog): JsonResponse
    {
        $data = $this->validateProduct($request);
        $tenant = Tenant::query()->find($catalog->tenant_id);
        if ($tenant) {
            app(SaasLimitGuard::class)->assertWithin($tenant, 'products');
        }

        $product = $this->catalog->create($catalog, $data);
        $product = $this->withStock(collect([$product]))->first() ?? $product;

        return response()->json(['data' => $product], 201);
    }

    public function show(Product $product): JsonResponse
    {
        $product->load($this->catalog->defaultRelations());
        $product = $this->withStock(collect([$product]))->first() ?? $product;

        return response()->json(['data' => $product]);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $data = $this->validateProduct($request, partial: true);

        $product = $this->catalog->update($product, $data);
        $product = $this->withStock(collect([$product]))->first() ?? $product;

        return response()->json(['data' => $product]);
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /**
     * @param  Collection<int, Product>  $products
     * @return Collection<int, Product>
     */
    private function withStock(Collection $products): Collection
    {
        if ($products->isEmpty() || ! Schema::hasTable('stock_balances')) {
            $products->each(fn (Product $product) => $product->setAttribute('stock', 0));

            return $products;
        }

        $stock = StockBalance::query()
            ->whereIn('product_id', $products->pluck('id'))
            ->selectRaw('product_id, SUM(quantity_on_hand) as qty')
            ->groupBy('product_id')
            ->pluck('qty', 'product_id');

        $products->each(function (Product $product) use ($stock): void {
            $product->setAttribute('stock', (int) ($stock[$product->id] ?? 0));
        });

        return $products;
    }

    /**
     * @return array<string, mixed>
     */
    private function listWith(Request $request): array
    {
        $with = [
            'category:id,name',
            'brand:id,name',
            'unitModel:id,name,code,symbol',
            'tax:id,name,code,rate,is_inclusive',
        ];

        if ($request->boolean('compact')) {
            $with['images'] = fn ($query) => $query->where('is_primary', true);

            return $with;
        }

        $with['images'] = fn ($query) => $query->select([
            'id', 'product_id', 'tenant_id', 'cdn_url', 'storage_path', 'is_primary', 'sort_order', 'alt_text',
        ]);
        $with['variants'] = fn ($query) => $query->select([
            'id', 'product_id', 'sku', 'name', 'base_price', 'is_active', 'sort_order',
        ]);

        return $with;
    }

    /**
     * @param  Collection<int, Product>  $products
     * @return Collection<int, Product>
     */
    private function presentList(Collection $products, bool $compact): Collection
    {
        if (! $compact) {
            return $products;
        }

        return $products->each(fn (Product $product) => $product->makeHidden(['description']));
    }

    /** @return array<string, mixed> */
    private function validateProduct(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        foreach (['category_id', 'brand_id', 'unit_id', 'tax_id'] as $field) {
            if ($request->exists($field) && $request->input($field) === '') {
                $request->merge([$field => null]);
            }
        }

        return $request->validate([
            'sku' => [$required, 'string', 'max:100'],
            'name' => [$required, 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'product_type' => ['nullable', 'string', Rule::in(Product::productTypes())],
            'brand_id' => ['nullable', 'uuid', 'exists:brands,id'],
            'unit_id' => ['nullable', 'uuid', 'exists:units,id'],
            'tax_id' => ['nullable', 'uuid', 'exists:taxes,id'],
            'barcode' => ['nullable', 'string', 'max:100'],
            'barcodes' => ['nullable', 'array'],
            'barcodes.*.barcode' => ['required_with:barcodes', 'string', 'max:100'],
            'barcodes.*.type' => ['nullable', 'string'],
            'barcodes.*.is_primary' => ['boolean'],
            'unit' => ['nullable', 'string', 'max:50'],
            'base_price' => [$required, 'integer', 'min:0'],
            'cost_price' => ['nullable', 'integer', 'min:0'],
            'prices' => ['nullable', 'array'],
            'prices.*.id' => ['nullable', 'uuid'],
            'prices.*.price_type' => ['required_with:prices', 'string'],
            'prices.*.amount' => ['required_with:prices', 'integer', 'min:0'],
            'prices.*.currency_code' => ['nullable', 'string', 'size:3'],
            'prices.*.store_id' => ['nullable', 'uuid'],
            'prices.*.min_quantity' => ['nullable', 'integer', 'min:1'],
            'prices.*.is_active' => ['boolean'],
            'category_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'is_active' => ['boolean'],
            'is_serialized' => ['boolean'],
            'track_batch' => ['boolean'],
            'track_expiration' => ['boolean'],
            'expiration_days' => ['nullable', 'integer', 'min:1'],
            'low_stock_threshold' => ['nullable', 'integer', 'min:0'],
            'metadata' => ['nullable', 'array'],
            'variants' => ['nullable', 'array'],
            'variants.*.id' => ['nullable', 'uuid'],
            'variants.*.sku' => ['required_with:variants', 'string', 'max:100'],
            'variants.*.name' => ['nullable', 'string'],
            'variants.*.size' => ['nullable', 'string', 'max:50'],
            'variants.*.color' => ['nullable', 'string', 'max:50'],
            'variants.*.color_hex' => ['nullable', 'string', 'max:7'],
            'variants.*.base_price' => ['required_with:variants', 'integer', 'min:0'],
            'variants.*.cost_price' => ['nullable', 'integer', 'min:0'],
            'bundle_items' => ['nullable', 'array'],
            'bundle_items.*.component_product_id' => ['required_with:bundle_items', 'uuid', 'exists:products,id'],
            'bundle_items.*.component_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'bundle_items.*.quantity' => ['nullable', 'numeric', 'min:0.0001'],
            'accompaniment_enabled' => ['boolean'],
        ]);
    }
}
