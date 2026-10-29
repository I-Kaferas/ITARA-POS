<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\Warehouse;
use App\Services\Inventory\StoreStockLocation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WarehouseController extends Controller
{
    public function __construct(
        private readonly StoreStockLocation $stockLocations,
    ) {}

    public function index(Branch $branch): JsonResponse
    {
        return response()->json([
            'data' => $branch->warehouses()->orderBy('name')->get(),
        ]);
    }

    public function indexAll(): JsonResponse
    {
        $this->stockLocations->attachMissing();

        return response()->json([
            'data' => Warehouse::query()
                ->whereNotNull('store_id')
                ->whereHas('store')
                ->orderBy('name')
                ->get(),
        ]);
    }

    public function store(Request $request, Branch $branch): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:50'],
            'is_active' => ['boolean'],
        ]);

        $warehouse = $branch->warehouses()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $warehouse], 201);
    }

    public function update(Request $request, Warehouse $warehouse): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:50'],
            'is_active' => ['boolean'],
        ]);

        $warehouse->update($data);

        return response()->json(['data' => $warehouse->fresh()]);
    }

    public function destroy(Warehouse $warehouse): JsonResponse
    {
        $warehouse->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
