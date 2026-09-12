<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Services\Catalog\ProductOptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductOptionController extends Controller
{
    public function __construct(
        private readonly ProductOptionService $options,
    ) {}

    public function show(Product $product): JsonResponse
    {
        $product->load('variants');

        return response()->json([
            'data' => [
                'product' => $product,
                'groups' => $product->metadata['option_groups'] ?? [],
                'variants' => $product->variants,
            ],
        ]);
    }

    public function transform(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'groups' => ['required', 'array', 'min:1', 'max:4'],
            'groups.*.name' => ['required', 'string', 'max:50'],
            'groups.*.values' => ['required', 'array', 'min:1', 'max:20'],
            'groups.*.values.*' => ['required', 'string', 'max:50'],
        ]);

        $transformed = $this->options->transform($product, $data['groups']);

        return response()->json([
            'data' => [
                'product' => $transformed,
                'groups' => $transformed->metadata['option_groups'] ?? [],
                'variants' => $transformed->variants,
            ],
        ]);
    }
}
