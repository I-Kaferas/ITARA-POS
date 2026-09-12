<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Tax;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TaxController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Tax::query()->orderBy('name');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:50'],
            'rate' => ['required', 'numeric', 'min:0', 'max:100'],
            'is_inclusive' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        $tax = Tax::query()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_inclusive' => $data['is_inclusive'] ?? false,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $tax], 201);
    }

    public function show(Tax $tax): JsonResponse
    {
        return response()->json(['data' => $tax]);
    }

    public function update(Request $request, Tax $tax): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:50'],
            'rate' => ['sometimes', 'numeric', 'min:0', 'max:100'],
            'is_inclusive' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        $tax->update($data);

        return response()->json(['data' => $tax->fresh()]);
    }

    public function destroy(Tax $tax): JsonResponse
    {
        $tax->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
