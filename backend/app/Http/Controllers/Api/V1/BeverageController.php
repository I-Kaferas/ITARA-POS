<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Warehouse;
use App\Services\Catalog\BeverageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BeverageController extends Controller
{
    public function __construct(
        private readonly BeverageService $beverages,
    ) {}

    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->beverages->dashboard($request->string('warehouse_id')->toString() ?: null),
        ]);
    }

    public function save(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'bottle_volume_ml' => ['required', 'integer', 'min:1', 'max:100000'],
            'cost_price' => ['required', 'integer', 'min:0'],
            'units' => ['required', 'array', 'min:1', 'max:12'],
            'units.*.name' => ['required', 'string', 'max:80'],
            'units.*.volume_ml' => ['required', 'integer', 'min:1'],
            'units.*.price' => ['required', 'integer', 'min:0'],
            'units.*.is_base' => ['nullable', 'boolean'],
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
            'stock_bottles' => ['nullable', 'integer', 'min:0'],
        ]);

        $saved = $this->beverages->save(
            $product,
            $data['bottle_volume_ml'],
            $data['cost_price'],
            $data['units'],
        );

        if (! empty($data['warehouse_id']) && isset($data['stock_bottles']) && (int) $data['stock_bottles'] > 0) {
            $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);
            $this->beverages->setStock($saved, $warehouse, (int) $data['stock_bottles'], $request->user()?->id);
        }

        return response()->json(['data' => $saved->load(['saleUnits', 'brand'])]);
    }

    public function destroy(Product $product): JsonResponse
    {
        $this->beverages->remove($product);

        return response()->json(['message' => 'Deleted.']);
    }
}
