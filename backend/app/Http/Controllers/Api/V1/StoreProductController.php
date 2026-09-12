<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreProduct;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StoreProductController extends Controller
{
    public function index(Store $store): JsonResponse
    {
        $items = StoreProduct::query()
            ->where('store_id', $store->id)
            ->with(['product.images'])
            ->get()
            ->map(fn (StoreProduct $sp) => [
                'id' => $sp->id,
                'product_id' => $sp->product_id,
                'is_available' => $sp->is_available,
                'price_override' => $sp->price_override,
                'effective_price' => $sp->effectivePrice(),
                'imported_at' => $sp->imported_at,
                'product' => $sp->product,
            ]);

        return response()->json(['data' => $items]);
    }

    public function import(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'product_ids' => ['required', 'array', 'min:1'],
            'product_ids.*' => ['uuid', 'exists:products,id'],
        ]);

        $imported = [];

        foreach ($data['product_ids'] as $productId) {
            $product = Product::query()->findOrFail($productId);
            $imported[] = $product->importToStore($store, importedBy: $request->user()?->id);
        }

        return response()->json(['data' => $imported], 201);
    }

    public function update(Request $request, Store $store, Product $product): JsonResponse
    {
        $data = $request->validate([
            'is_available' => ['boolean'],
            'price_override' => ['nullable', 'integer', 'min:0'],
        ]);

        $storeProduct = StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('product_id', $product->id)
            ->firstOrFail();

        $storeProduct->update($data);

        return response()->json(['data' => $storeProduct->fresh()->load('product')]);
    }

    public function destroy(Store $store, Product $product): JsonResponse
    {
        StoreProduct::query()
            ->where('store_id', $store->id)
            ->where('product_id', $product->id)
            ->delete();

        return response()->json(['message' => 'Removed from store.']);
    }
}
