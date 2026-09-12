<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Unit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UnitController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Unit::query()->orderBy('name');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'max:20'],
            'name' => ['required', 'string', 'max:100'],
            'symbol' => ['nullable', 'string', 'max:20'],
            'is_fractional' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        $unit = Unit::query()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_fractional' => $data['is_fractional'] ?? false,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $unit], 201);
    }

    public function show(Unit $unit): JsonResponse
    {
        return response()->json(['data' => $unit]);
    }

    public function update(Request $request, Unit $unit): JsonResponse
    {
        $data = $request->validate([
            'code' => ['sometimes', 'string', 'max:20'],
            'name' => ['sometimes', 'string', 'max:100'],
            'symbol' => ['nullable', 'string', 'max:20'],
            'is_fractional' => ['boolean'],
            'is_active' => ['boolean'],
        ]);

        $unit->update($data);

        return response()->json(['data' => $unit->fresh()]);
    }

    public function destroy(Unit $unit): JsonResponse
    {
        $unit->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
