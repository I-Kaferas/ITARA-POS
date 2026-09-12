<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\Company;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CatalogController extends Controller
{
    public function index(Company $company): JsonResponse
    {
        return response()->json([
            'data' => $company->catalogs()->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request, Company $company): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'is_default' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        if ($data['is_default'] ?? false) {
            $company->catalogs()->update(['is_default' => false]);
        }

        $catalog = $company->catalogs()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_default' => $data['is_default'] ?? false,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $catalog], 201);
    }

    public function show(Catalog $catalog): JsonResponse
    {
        return response()->json(['data' => $catalog->load('company')]);
    }

    public function update(Request $request, Catalog $catalog): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'is_default' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        if ($data['is_default'] ?? false) {
            Catalog::query()
                ->where('company_id', $catalog->company_id)
                ->whereKeyNot($catalog->id)
                ->update(['is_default' => false]);
        }

        $catalog->update($data);

        return response()->json(['data' => $catalog->fresh()]);
    }

    public function destroy(Catalog $catalog): JsonResponse
    {
        $catalog->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
