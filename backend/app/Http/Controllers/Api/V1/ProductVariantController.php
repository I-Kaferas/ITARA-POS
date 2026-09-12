<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Services\Catalog\BarcodeService;
use App\Services\Catalog\PriceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductVariantController extends Controller
{
    public function __construct(
        private BarcodeService $barcodes,
        private PriceService $prices,
    ) {}

    public function index(Product $product): JsonResponse
    {
        return response()->json([
            'data' => $product->variants()->with(['barcodes', 'prices'])->get(),
        ]);
    }

    public function store(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'sku' => ['required', 'string', 'max:100'],
            'name' => ['nullable', 'string', 'max:255'],
            'size' => ['nullable', 'string', 'max:50'],
            'color' => ['nullable', 'string', 'max:50'],
            'color_hex' => ['nullable', 'string', 'max:7'],
            'base_price' => ['required', 'integer', 'min:0'],
            'cost_price' => ['nullable', 'integer', 'min:0'],
            'sort_order' => ['integer'],
            'is_active' => ['boolean'],
            'attributes' => ['nullable', 'array'],
            'barcodes' => ['nullable', 'array'],
            'prices' => ['nullable', 'array'],
        ]);

        $variant = $product->variants()->create([
            'tenant_id' => $product->tenant_id,
            'sku' => $data['sku'],
            'name' => $data['name'] ?? null,
            'size' => $data['size'] ?? null,
            'color' => $data['color'] ?? null,
            'color_hex' => $data['color_hex'] ?? null,
            'base_price' => $data['base_price'],
            'cost_price' => $data['cost_price'] ?? 0,
            'sort_order' => $data['sort_order'] ?? 0,
            'is_active' => $data['is_active'] ?? true,
            'attributes' => $data['attributes'] ?? null,
        ]);

        if (! empty($data['barcodes'])) {
            $this->barcodes->syncForModel($variant, $data['barcodes']);
        }

        if (! empty($data['prices'])) {
            $this->prices->syncForModel($variant, $data['prices']);
        }

        return response()->json(['data' => $variant->load(['barcodes', 'prices'])], 201);
    }

    public function show(ProductVariant $variant): JsonResponse
    {
        return response()->json([
            'data' => $variant->load(['product', 'barcodes', 'prices']),
        ]);
    }

    public function update(Request $request, ProductVariant $variant): JsonResponse
    {
        $data = $request->validate([
            'sku' => ['sometimes', 'string', 'max:100'],
            'name' => ['nullable', 'string', 'max:255'],
            'size' => ['nullable', 'string', 'max:50'],
            'color' => ['nullable', 'string', 'max:50'],
            'color_hex' => ['nullable', 'string', 'max:7'],
            'base_price' => ['sometimes', 'integer', 'min:0'],
            'cost_price' => ['nullable', 'integer', 'min:0'],
            'sort_order' => ['integer'],
            'is_active' => ['boolean'],
            'attributes' => ['nullable', 'array'],
            'barcodes' => ['nullable', 'array'],
            'prices' => ['nullable', 'array'],
        ]);

        $variant->update(collect($data)->except(['barcodes', 'prices'])->all());

        if (isset($data['barcodes'])) {
            $this->barcodes->syncForModel($variant, $data['barcodes']);
        }

        if (isset($data['prices'])) {
            $this->prices->syncForModel($variant, $data['prices']);
        }

        return response()->json(['data' => $variant->fresh()->load(['barcodes', 'prices'])]);
    }

    public function destroy(ProductVariant $variant): JsonResponse
    {
        $variant->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
