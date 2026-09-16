<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Services\Catalog\ProductAccompanimentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductAccompanimentController extends Controller
{
    public function __construct(private readonly ProductAccompanimentService $accompaniments) {}

    public function index(): JsonResponse
    {
        return response()->json([
            'data' => $this->accompaniments->list(),
        ]);
    }

    public function candidates(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->accompaniments->candidates($request->string('exclude_product_id')->toString() ?: null),
        ]);
    }

    public function config(Product $product): JsonResponse
    {
        return response()->json([
            'data' => $this->accompaniments->forProduct($product),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
            'accompaniment_product_ids' => ['present', 'array'],
            'accompaniment_product_ids.*' => ['uuid', 'exists:products,id'],
        ]);

        $product = Product::query()->findOrFail($data['product_id']);

        return response()->json([
            'data' => $this->accompaniments->sync($product, $data['accompaniment_product_ids']),
        ], 201);
    }

    public function sync(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'accompaniment_product_ids' => ['present', 'array'],
            'accompaniment_product_ids.*' => ['uuid', 'exists:products,id'],
        ]);

        return response()->json([
            'data' => $this->accompaniments->sync($product, $data['accompaniment_product_ids']),
        ]);
    }
}
