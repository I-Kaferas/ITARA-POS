<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\InventoryMovementType;
use App\Http\Controllers\Controller;
use App\Models\StockAdjustment;
use App\Models\Warehouse;
use App\Services\Inventory\StockAdjustmentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class StockAdjustmentController extends Controller
{
    public function __construct(
        private readonly StockAdjustmentService $adjustmentService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = StockAdjustment::query()
            ->with(['warehouse:id,name,code'])
            ->orderByDesc('created_at');

        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->string('warehouse_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        if ($request->boolean('issues_only')) {
            $query->whereIn('movement_type', ['ADJUSTMENT_OUT', 'DAMAGE', 'LOSS', 'EXPIRED']);
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function show(StockAdjustment $stockAdjustment): JsonResponse
    {
        return response()->json([
            'data' => $stockAdjustment->load([
                'warehouse',
                'movements.product:id,sku,name',
                'items.product:id,sku,name',
                'performedBy:id,name',
                'confirmedBy:id,name',
                'approvedBy:id,name',
            ]),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $adjustmentTypeValues = array_map(
            fn (InventoryMovementType $t) => $t->value,
            InventoryMovementType::adjustmentTypes(),
        );

        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'movement_type' => ['required', Rule::in($adjustmentTypeValues)],
            'reason' => ['nullable', 'string', 'max:1000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.batch_id' => ['nullable', 'uuid', 'exists:batches,id'],
            'items.*.unit_cost' => ['nullable', 'integer', 'min:0'],
            'items.*.notes' => ['nullable', 'string', 'max:500'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);

        $adjustment = $this->adjustmentService->create(
            warehouse: $warehouse,
            movementType: InventoryMovementType::from($data['movement_type']),
            items: $data['items'],
            performedBy: $request->user(),
            reason: $data['reason'] ?? null,
        );

        return response()->json(['data' => $adjustment], 201);
    }

    public function confirm(Request $request, StockAdjustment $stockAdjustment): JsonResponse
    {
        return response()->json([
            'data' => $this->adjustmentService->confirm($stockAdjustment, $request->user()),
        ]);
    }

    public function complete(Request $request, StockAdjustment $stockAdjustment): JsonResponse
    {
        return response()->json([
            'data' => $this->adjustmentService->complete($stockAdjustment, $request->user()),
        ]);
    }
}
