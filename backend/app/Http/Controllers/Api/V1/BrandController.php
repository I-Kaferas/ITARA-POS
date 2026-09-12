<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Brand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class BrandController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Brand::query()->orderBy('name');

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
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'is_active' => ['boolean'],
        ]);

        $brand = Brand::query()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'slug' => $data['slug'] ?? Str::slug($data['name']),
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $brand], 201);
    }

    public function show(Brand $brand): JsonResponse
    {
        return response()->json(['data' => $brand]);
    }

    public function update(Request $request, Brand $brand): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'slug' => ['sometimes', 'string', 'max:100'],
            'description' => ['nullable', 'string'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'is_active' => ['boolean'],
        ]);

        $brand->update($data);

        return response()->json(['data' => $brand->fresh()]);
    }

    public function destroy(Brand $brand): JsonResponse
    {
        $brand->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
