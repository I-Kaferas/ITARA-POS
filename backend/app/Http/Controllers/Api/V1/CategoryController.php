<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    public function index(Catalog $catalog): JsonResponse
    {
        $categories = $catalog->categories()
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        $byParent = $categories->groupBy(fn (Category $category) => $category->parent_id ?? '');

        $build = function (?string $parentId) use (&$build, $byParent) {
            return ($byParent->get($parentId ?? '') ?? collect())
                ->map(function (Category $category) use ($build) {
                    $category->setRelation('children', $build($category->id));

                    return $category;
                })
                ->values();
        };

        return response()->json(['data' => $build(null)]);
    }

    public function show(Category $category): JsonResponse
    {
        return response()->json([
            'data' => $category->load(['parent', 'children', 'catalog']),
        ]);
    }

    public function store(Request $request, Catalog $catalog): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:100'],
            'parent_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'sort_order' => ['integer'],
            'is_active' => ['boolean'],
        ]);

        $category = $catalog->categories()->create([
            'tenant_id' => app('tenant.id'),
            'name' => $data['name'],
            'slug' => $data['slug'] ?? Str::slug($data['name']),
            'parent_id' => $data['parent_id'] ?? null,
            'sort_order' => $data['sort_order'] ?? 0,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $category], 201);
    }

    public function update(Request $request, Category $category): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'slug' => ['sometimes', 'string', 'max:100'],
            'parent_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'sort_order' => ['integer'],
            'is_active' => ['boolean'],
        ]);

        $category->update($data);

        return response()->json(['data' => $category->fresh()]);
    }

    public function destroy(Category $category): JsonResponse
    {
        $category->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
