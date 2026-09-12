<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\InventoryAlertType;
use App\Http\Controllers\Controller;
use App\Models\InventoryAlert;
use App\Models\Warehouse;
use App\Services\Inventory\StockAlertService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class InventoryAlertController extends Controller
{
    public function __construct(
        private readonly StockAlertService $alertService,
    ) {}

    public function types(): JsonResponse
    {
        return response()->json([
            'data' => collect(InventoryAlertType::cases())->map(fn (InventoryAlertType $type) => [
                'value' => $type->value,
                'label' => $type->label(),
            ])->values(),
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $query = InventoryAlert::query()
            ->with([
                'product:id,sku,name',
                'warehouse:id,name,code',
                'batch:id,batch_number,expires_at',
            ])
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        } else {
            $query->whereIn('status', ['active', 'acknowledged']);
        }

        if ($request->filled('alert_type')) {
            $query->where('alert_type', $request->string('alert_type'));
        }

        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->string('warehouse_id'));
        }

        if ($request->filled('product_id')) {
            $query->where('product_id', $request->string('product_id'));
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function show(InventoryAlert $inventoryAlert): JsonResponse
    {
        return response()->json([
            'data' => $inventoryAlert->load([
                'product',
                'warehouse',
                'batch',
                'acknowledgedBy:id,name',
            ]),
        ]);
    }

    public function acknowledge(Request $request, InventoryAlert $inventoryAlert): JsonResponse
    {
        $alert = $this->alertService->acknowledge($inventoryAlert, $request->user()?->id);

        return response()->json(['data' => $alert]);
    }

    public function resolve(InventoryAlert $inventoryAlert): JsonResponse
    {
        $alert = $this->alertService->resolve($inventoryAlert);

        return response()->json(['data' => $alert]);
    }

    public function refresh(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);
        $this->alertService->evaluateWarehouse($warehouse);

        return response()->json(['message' => 'Alerts refreshed.']);
    }
}
