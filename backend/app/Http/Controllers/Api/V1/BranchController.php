<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\Company;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BranchController extends Controller
{
    public function index(Company $company): JsonResponse
    {
        return response()->json([
            'data' => $company->branches()->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request, Company $company): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:50'],
            'is_active' => ['boolean'],
        ]);

        $branch = $company->branches()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $branch], 201);
    }

    public function update(Request $request, Branch $branch): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:50'],
            'is_active' => ['boolean'],
        ]);

        $branch->update($data);

        return response()->json(['data' => $branch->fresh()]);
    }

    public function destroy(Branch $branch): JsonResponse
    {
        $branch->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
