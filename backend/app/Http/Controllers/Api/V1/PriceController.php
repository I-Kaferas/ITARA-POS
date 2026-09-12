<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Price;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Services\Catalog\PriceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PriceController extends Controller
{
    public function __construct(private PriceService $prices) {}

    public function indexForProduct(Product $product): JsonResponse
    {
        return response()->json([
            'data' => $product->prices()->with('store')->orderBy('price_type')->get(),
        ]);
    }

    public function storeForProduct(Request $request, Product $product): JsonResponse
    {
        $data = $this->validatePrice($request);

        $price = $this->prices->createOrUpdate($product, $data);

        return response()->json(['data' => $price->load('store')], 201);
    }

    public function indexForVariant(ProductVariant $variant): JsonResponse
    {
        return response()->json([
            'data' => $variant->prices()->with('store')->orderBy('price_type')->get(),
        ]);
    }

    public function storeForVariant(Request $request, ProductVariant $variant): JsonResponse
    {
        $data = $this->validatePrice($request);

        $price = $this->prices->createOrUpdate($variant, $data);

        return response()->json(['data' => $price->load('store')], 201);
    }

    public function update(Request $request, Price $price): JsonResponse
    {
        $data = $this->validatePrice($request, partial: true);
        $model = $price->priceable;

        if (! $model instanceof Product && ! $model instanceof ProductVariant) {
            abort(404);
        }

        $updated = $this->prices->createOrUpdate($model, $data, $price);

        return response()->json(['data' => $updated->load('store')]);
    }

    public function destroy(Price $price): JsonResponse
    {
        $price->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    /** @return array<string, mixed> */
    private function validatePrice(Request $request, bool $partial = false): array
    {
        $sometimes = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'price_type' => [$sometimes, 'string', Rule::in(array_keys(config('product_types.price_types')))],
            'amount' => [$sometimes, 'integer', 'min:0'],
            'currency_code' => ['nullable', 'string', 'size:3'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
            'min_quantity' => ['nullable', 'integer', 'min:1'],
            'valid_from' => ['nullable', 'date'],
            'valid_until' => ['nullable', 'date', 'after_or_equal:valid_from'],
            'is_active' => ['boolean'],
        ]);
    }
}
