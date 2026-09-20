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
        $this->ensureSingleDefault($company);

        return response()->json([
            'data' => $company->catalogs()->orderByDesc('is_default')->orderBy('name')->get(),
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

        $wantDefault = $data['is_default']
            ?? ! $company->catalogs()->where('is_default', true)->exists();

        if ($wantDefault) {
            $company->catalogs()->update(['is_default' => false]);
        }

        $catalog = $company->catalogs()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'store_id' => null,
            'is_default' => $wantDefault,
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

        if (($data['is_default'] ?? false) === true) {
            Catalog::query()
                ->where('company_id', $catalog->company_id)
                ->whereKeyNot($catalog->id)
                ->update(['is_default' => false]);
        }

        if (
            array_key_exists('is_default', $data)
            && $data['is_default'] === false
            && $catalog->is_default
            && ! Catalog::query()
                ->where('company_id', $catalog->company_id)
                ->where('is_default', true)
                ->whereKeyNot($catalog->id)
                ->exists()
        ) {
            $data['is_default'] = true;
        }

        $catalog->update($data);

        return response()->json(['data' => $catalog->fresh()]);
    }

    public function destroy(Catalog $catalog): JsonResponse
    {
        $companyId = $catalog->company_id;
        $wasDefault = $catalog->is_default;
        $catalog->delete();

        if ($wasDefault) {
            Catalog::query()
                ->where('company_id', $companyId)
                ->orderBy('created_at')
                ->first()
                ?->update(['is_default' => true]);
        }

        return response()->json(['message' => 'Deleted.']);
    }

    private function ensureSingleDefault(Company $company): void
    {
        $defaults = $company->catalogs()
            ->where('is_default', true)
            ->orderBy('created_at')
            ->get(['id']);

        if ($defaults->count() <= 1) {
            return;
        }

        $keepId = $defaults->first()?->id;
        $company->catalogs()
            ->where('is_default', true)
            ->whereKeyNot($keepId)
            ->update(['is_default' => false]);
    }
}
