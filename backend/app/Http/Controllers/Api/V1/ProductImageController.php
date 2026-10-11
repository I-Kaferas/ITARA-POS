<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\GalleryImage;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\Tenant;
use App\Services\Catalog\ProductImageService;
use App\Services\Platform\SaasLimitGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use InvalidArgumentException;

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

        $tenant = Tenant::query()->find($product->tenant_id);
        if ($tenant && $request->file('image')) {
            app(SaasLimitGuard::class)->assertStorage($tenant, (int) $request->file('image')->getSize());
        }

        $image = $this->imageService->upload(
            $product,
            $request->file('image'),
            $request->boolean('is_primary') ?: null,
        );

        return response()->json(['data' => $image], 201);
    }

    public function storeFromGallery(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'gallery_image_id' => ['required', 'uuid'],
            'is_primary' => ['boolean'],
        ]);

        $gallery = GalleryImage::query()->findOrFail($data['gallery_image_id']);

        try {
            $image = $this->imageService->attachFromGallery($product, $gallery);
        } catch (InvalidArgumentException $exception) {
            return response()->json([
                'message' => $exception->getMessage(),
            ], 422);
        }

        return response()->json(['data' => $image], 201);
    }

    public function storeFromProductImage(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'product_image_id' => ['required', 'uuid'],
        ]);

        $source = ProductImage::query()->findOrFail($data['product_image_id']);

        try {
            $image = $this->imageService->attachFromProductImage($product, $source);
        } catch (InvalidArgumentException $exception) {
            return response()->json([
                'message' => $exception->getMessage(),
            ], 422);
        }

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
