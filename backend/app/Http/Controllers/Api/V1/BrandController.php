<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\V1\Concerns\ResolvesStoreIds;
use App\Http\Controllers\Controller;
use App\Models\Brand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class BrandController extends Controller
{
    use ResolvesStoreIds;

    public function index(Request $request): JsonResponse
    {
        $storeId = $this->resolveStoreId($request);

        $query = Brand::query()->orderBy('name');

        if ($storeId) {
            $query->where('store_id', $storeId);
        } elseif (! $request->boolean('all_stores')) {
            $query->whereNotNull('store_id');
        }

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        if ($search = $request->string('search')->toString()) {
            $query->where('name', 'like', "%{$search}%");
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $storeIds = $this->resolveStoreIds($request, required: true);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'is_active' => ['boolean'],
            'store_id' => ['nullable', 'uuid'],
            'store_ids' => ['nullable', 'array'],
            'store_ids.*' => ['uuid'],
        ]);

        $slug = $data['slug'] ?? Str::slug($data['name']);
        $created = DB::transaction(function () use ($storeIds, $data, $slug) {
            $rows = [];
            foreach ($storeIds as $storeId) {
                $rows[] = Brand::query()->firstOrCreate(
                    [
                        'tenant_id' => app('tenant.id'),
                        'store_id' => $storeId,
                        'slug' => $slug,
                    ],
                    [
                        'name' => $data['name'],
                        'description' => $data['description'] ?? null,
                        'logo_url' => $data['logo_url'] ?? null,
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

    public function show(Brand $brand): JsonResponse
    {
        return response()->json(['data' => $brand]);
    }

    public function update(Request $request, Brand $brand): JsonResponse
    {
        $storeIds = $this->targetStoreIds($request, $brand->store_id);
        $data = $this->withoutStoreFields($request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'slug' => ['sometimes', 'string', 'max:100'],
            'description' => ['nullable', 'string'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'is_active' => ['boolean'],
            'store_id' => ['nullable', 'uuid'],
            'store_ids' => ['nullable', 'array'],
            'store_ids.*' => ['uuid'],
        ]));

        $updated = DB::transaction(function () use ($brand, $storeIds, $data) {
            $originalSlug = $brand->slug;
            $newSlug = $data['slug'] ?? $originalSlug;
            $rows = [];

            foreach ($storeIds as $storeId) {
                $query = Brand::query()
                    ->where('tenant_id', $brand->tenant_id)
                    ->where('store_id', $storeId);

                $target = $storeId === $brand->store_id
                    ? $brand
                    : ($query->clone()->where('slug', $originalSlug)->first()
                        ?? $query->clone()->where('slug', $newSlug)->first());

                if ($target) {
                    $target->update($data);
                    $rows[] = $target->fresh();
                    continue;
                }

                $rows[] = Brand::query()->create([
                    'tenant_id' => $brand->tenant_id,
                    'store_id' => $storeId,
                    'name' => $data['name'] ?? $brand->name,
                    'slug' => $newSlug,
                    'description' => array_key_exists('description', $data) ? $data['description'] : $brand->description,
                    'logo_url' => array_key_exists('logo_url', $data) ? $data['logo_url'] : $brand->logo_url,
                    'is_active' => $data['is_active'] ?? $brand->is_active,
                ]);
            }

            return $rows;
        });

        return response()->json([
            'data' => $brand->fresh(),
            'updated_count' => count($updated),
        ]);
    }

    public function destroy(Brand $brand): JsonResponse
    {
        $brand->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
