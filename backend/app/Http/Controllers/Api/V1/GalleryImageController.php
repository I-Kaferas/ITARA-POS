<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\GalleryImage;
use App\Services\Catalog\GalleryImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GalleryImageController extends Controller
{
    public function __construct(private GalleryImageService $images) {}

    public function index(Request $request): JsonResponse
    {
        $query = GalleryImage::query()->latest();

        if ($request->filled('catalog_id')) {
            $query->where('catalog_id', $request->string('catalog_id'));
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'image' => ['required', 'file', 'image', 'max:5120'],
            'catalog_id' => ['nullable', 'uuid'],
        ]);

        $catalog = $request->filled('catalog_id')
            ? Catalog::query()->findOrFail((string) $request->string('catalog_id'))
            : null;

        $image = $this->images->upload($catalog, $request->file('image'));

        return response()->json(['data' => $image], 201);
    }

    public function destroy(GalleryImage $galleryImage): JsonResponse
    {
        $this->images->delete($galleryImage);

        return response()->json(['message' => 'Deleted.']);
    }
}
