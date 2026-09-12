<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductImage;
use App\Services\Catalog\ProductImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductImageController extends Controller
{
    public function __construct(private ProductImageService $imageService) {}

    public function index(Product $product): JsonResponse
    {
        return response()->json(['data' => $product->images()->ordered()->get()]);
    }

    public function store(Request $request, Product $product): JsonResponse
    {
        $request->validate([
            'image' => ['required', 'file', 'image', 'max:5120'],
            'is_primary' => ['boolean'],
        ]);

        $image = $this->imageService->upload(
            $product,
            $request->file('image'),
            $request->boolean('is_primary') ?: null,
        );

        return response()->json(['data' => $image], 201);
    }

    public function setPrimary(ProductImage $productImage): JsonResponse
    {
        $this->imageService->setPrimary($productImage);

        return response()->json(['data' => $productImage->fresh()]);
    }

    public function reorder(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'image_ids' => ['required', 'array'],
            'image_ids.*' => ['uuid'],
        ]);

        $this->imageService->reorder($product, $data['image_ids']);

        return response()->json([
            'data' => $product->images()->ordered()->get(),
        ]);
    }

    public function destroy(ProductImage $productImage): JsonResponse
    {
        $this->imageService->delete($productImage);

        return response()->json(['message' => 'Deleted.']);
    }
}
