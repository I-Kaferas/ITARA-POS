<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\V1\Concerns\ResolvesStoreIds;
use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class CategoryController extends Controller
{
    use ResolvesStoreIds;

    public function index(Request $request, Catalog $catalog): JsonResponse
    {
        $storeId = $this->resolveStoreId($request);

        $query = $catalog->categories()
            ->orderBy('sort_order')
            ->orderBy('name');

        if ($storeId) {
            $query->where('store_id', $storeId);
        }

        $categories = $query->get();

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
            'data' => $category->load(['parent', 'children', 'catalog', 'store']),
        ]);
    }

    public function store(Request $request, Catalog $catalog): JsonResponse
    {
        $storeIds = $this->resolveStoreIds($request, required: true);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:100'],
            'parent_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'sort_order' => ['integer'],
            'is_active' => ['boolean'],
            'store_id' => ['nullable', 'uuid'],
            'store_ids' => ['nullable', 'array'],
            'store_ids.*' => ['uuid'],
        ]);

        $parent = ! empty($data['parent_id'])
            ? Category::query()->findOrFail($data['parent_id'])
            : null;

        if ($parent && $parent->catalog_id !== $catalog->id) {
            return response()->json(['message' => 'Parent category must belong to the same catalog.'], 422);
        }

        $slug = $data['slug'] ?? Str::slug($data['name']);

        $created = DB::transaction(function () use ($storeIds, $catalog, $data, $parent, $slug) {
            $rows = [];

            foreach ($storeIds as $storeId) {
                $parentId = $this->parentIdForStore($parent, $catalog->id, $storeId);

                $rows[] = Category::query()->firstOrCreate(
                    [
                        'catalog_id' => $catalog->id,
                        'store_id' => $storeId,
                        'slug' => $slug,
                    ],
                    [
                        'tenant_id' => app('tenant.id'),
                        'name' => $data['name'],
                        'parent_id' => $parentId,
                        'sort_order' => $data['sort_order'] ?? 0,
                        'is_active' => $data['is_active'] ?? true,
                    ],
                );
            }

            return $rows;
        });

        return response()->json([
            'data' => $created[0],
            'created_count' => count($created),
        ], 201);
    }

    public function update(Request $request, Category $category): JsonResponse
    {
        $storeIds = $this->targetStoreIds($request, $category->store_id);
        $data = $this->withoutStoreFields($request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'slug' => [
                'sometimes',
                'string',
                'max:100',
                Rule::unique('categories', 'slug')->where(fn ($q) => $q
                    ->where('catalog_id', $category->catalog_id)
                    ->where('store_id', $category->store_id)
                    ->whereNull('deleted_at'))->ignore($category->id),
            ],
            'parent_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'sort_order' => ['integer'],
            'is_active' => ['boolean'],
            'store_id' => ['nullable', 'uuid'],
            'store_ids' => ['nullable', 'array'],
            'store_ids.*' => ['uuid'],
        ]));

        $parent = null;
        if (array_key_exists('parent_id', $data) && $data['parent_id']) {
            $parent = Category::query()->findOrFail($data['parent_id']);
            if ($parent->catalog_id !== $category->catalog_id) {
                return response()->json(['message' => 'Parent category must belong to the same catalog.'], 422);
            }
        }

        $updated = DB::transaction(function () use ($category, $storeIds, $data, $parent) {
            $originalSlug = $category->slug;
            $newSlug = $data['slug'] ?? $originalSlug;
            $rows = [];

            foreach ($storeIds as $storeId) {
                $payload = $data;
                if (array_key_exists('parent_id', $payload)) {
                    $payload['parent_id'] = $this->parentIdForStore($parent, $category->catalog_id, $storeId);
                }

                $query = Category::query()
                    ->where('catalog_id', $category->catalog_id)
                    ->where('store_id', $storeId);

                $target = $storeId === $category->store_id
                    ? $category
                    : ($query->clone()->where('slug', $originalSlug)->first()
                        ?? $query->clone()->where('slug', $newSlug)->first());

                if ($target) {
                    $target->update($payload);
                    $rows[] = $target->fresh();
                    continue;
                }

                $rows[] = Category::query()->create([
                    'tenant_id' => $category->tenant_id,
                    'catalog_id' => $category->catalog_id,
                    'store_id' => $storeId,
                    'name' => $payload['name'] ?? $category->name,
                    'slug' => $newSlug,
                    'parent_id' => array_key_exists('parent_id', $payload) ? $payload['parent_id'] : null,
                    'sort_order' => $payload['sort_order'] ?? $category->sort_order,
                    'is_active' => $payload['is_active'] ?? $category->is_active,
                ]);
            }

            return $rows;
        });

        return response()->json([
            'data' => $category->fresh(),
            'updated_count' => count($updated),
        ]);
    }

    public function destroy(Category $category): JsonResponse
    {
        $category->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    private function parentIdForStore(?Category $parent, string $catalogId, string $storeId): ?string
    {
        if (! $parent) {
            return null;
        }

        if ($parent->store_id === $storeId) {
            return $parent->id;
        }

        return Category::query()
            ->where('catalog_id', $catalogId)
            ->where('store_id', $storeId)
            ->where('slug', $parent->slug)
            ->value('id');
    }
}
