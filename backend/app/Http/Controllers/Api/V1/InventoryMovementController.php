<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\InventoryMovementType;
use App\Http\Controllers\Controller;
use App\Models\InventoryMovement;
use App\Models\Product;
use App\Models\Warehouse;
use App\Services\Inventory\InventoryMovementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class InventoryMovementController extends Controller
{
    public function __construct(
        private readonly InventoryMovementService $movementService,
    ) {}

    public function types(): JsonResponse
    {
        return response()->json([
            'data' => collect(InventoryMovementType::cases())->map(fn (InventoryMovementType $type) => [
                'value' => $type->value,
                'spec_code' => $type->specCode(),
                'direction' => $type->isInbound() ? 'in' : 'out',
            ])->values(),
        ]);
    }

    public function index(Request $request, Warehouse $warehouse): JsonResponse
    {
        $query = InventoryMovement::query()
            ->where('warehouse_id', $warehouse->id)
            ->with(['product:id,sku,name', 'productVariant:id,sku,name', 'batch:id,batch_number', 'performedBy:id,name'])
            ->orderByDesc('occurred_at');

        if ($request->filled('product_id')) {
            $query->where('product_id', $request->string('product_id'));
        }

        if ($request->filled('movement_type')) {
            $query->where('movement_type', InventoryMovementType::parse($request->string('movement_type'))->value);
        }

        if ($request->filled('product_id')) {
            return response()->json([
                'data' => [
                    'data' => $this->ledgerWithBalance($query),
                ],
            ]);
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function store(Request $request, Warehouse $warehouse): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
            'movement_type' => ['required', Rule::in([...InventoryMovementType::values(), 'OPENING'])],
            'quantity' => ['required', 'integer', 'min:1'],
            'product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'batch_id' => ['nullable', 'uuid', 'exists:batches,id'],
            'serial_number_id' => ['nullable', 'uuid', 'exists:serial_numbers,id'],
            'unit_cost' => ['nullable', 'integer', 'min:0'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'occurred_at' => ['nullable', 'date'],
        ]);

        $product = Product::query()->findOrFail($data['product_id']);
        $movementType = InventoryMovementType::parse($data['movement_type']);

        $movement = $this->movementService->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => $movementType,
            'quantity' => $data['quantity'],
            'product_variant_id' => $data['product_variant_id'] ?? null,
            'batch_id' => $data['batch_id'] ?? null,
            'serial_number_id' => $data['serial_number_id'] ?? null,
            'unit_cost' => $data['unit_cost'] ?? null,
            'performed_by' => $request->user()?->id,
            'notes' => $data['notes'] ?? null,
            'occurred_at' => isset($data['occurred_at']) ? new \DateTimeImmutable($data['occurred_at']) : null,
        ]);

        return response()->json(['data' => $movement->load(['product', 'warehouse'])], 201);
    }

    /**
     * Chronological ledger: each line keeps its signed quantity and the stock after it.
     * Example: +100 OPENING (100), -3 SALE (97).
     *
     * @return list<InventoryMovement>
     */
    private function ledgerWithBalance($query): array
    {
        $running = 0;

        return $query
            ->reorder()
            ->orderBy('occurred_at')
            ->orderBy('id')
            ->get()
            ->each(function (InventoryMovement $movement) use (&$running): void {
                $running += (int) $movement->quantity;
                $movement->setAttribute('balance_after', $running);
            })
            ->all();
    }
}
