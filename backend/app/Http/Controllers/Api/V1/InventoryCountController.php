<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\InventoryCount;
use App\Models\Product;
use Illuminate\Validation\Rule;
use App\Models\Warehouse;
use App\Services\Inventory\CycleCountService;
use App\Services\Inventory\FullPhysicalCountService;
use App\Services\Inventory\InventoryCountService;
use App\Services\Inventory\StockLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InventoryCountController extends Controller
{
    public function __construct(
        private readonly InventoryCountService $countService,
        private readonly StockLedgerService $ledgerService,
        private readonly FullPhysicalCountService $fullCountService,
        private readonly CycleCountService $cycleCountService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = InventoryCount::query()
            ->with(['warehouse:id,name,code'])
            ->withCount('items')
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function show(InventoryCount $inventoryCount): JsonResponse
    {
        return response()->json([
            'data' => $inventoryCount->load([
                'warehouse',
                'items.product:id,sku,name,category_id,unit,bottle_volume_ml,cost_price',
                'items.product.category:id,name',
                'items.product.saleUnits:id,product_id,name,volume_ml,is_base',
                'items.saleUnit:id,name,volume_ml',
                'performedBy:id,name',
                'confirmedBy:id,name',
                'approvedBy:id,name',
            ]),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'count_type' => ['required', 'string', Rule::in(['opening', 'full', 'cycle', 'spot'])],
            'counted_at' => ['required', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:0'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);

        $count = $this->countService->create(
            warehouse: $warehouse,
            items: $data['items'],
            performedBy: $request->user(),
            notes: $data['notes'] ?? null,
            countType: $data['count_type'],
            countedAt: $data['counted_at'],
        );

        return response()->json(['data' => $count], 201);
    }

    public function open(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'counted_at' => ['required', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.sale_unit_id' => ['nullable', 'uuid', 'exists:product_sale_units,id'],
            'items.*.unit_cost' => ['nullable', 'integer', 'min:0'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);
        $result = $this->countService->open(
            warehouse: $warehouse,
            items: $data['items'],
            performedBy: $request->user(),
            notes: $data['notes'] ?? null,
            countedAt: $data['counted_at'],
        );

        return response()->json([
            'message' => 'Stock initial créé avec succès.',
            'data' => $result['count'],
            'lines' => $result['lines'],
        ], 201);
    }

    public function openedProducts(Warehouse $warehouse): JsonResponse
    {
        return response()->json([
            'data' => $this->countService->openedProductIds($warehouse),
        ]);
    }

    public function ledger(Request $request, Warehouse $warehouse): JsonResponse
    {
        return response()->json([
            'data' => $this->ledgerService->summarize(
                $warehouse,
                $request->string('product_id')->toString() ?: null,
            ),
        ]);
    }

    public function update(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:0'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
        ]);

        return response()->json([
            'data' => $this->countService->update($inventoryCount, $data['items']),
        ]);
    }

    public function startFull(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'counted_at' => ['required', 'date'],
            'zone' => ['nullable', 'string', 'max:120'],
            'category_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'lock_movements' => ['nullable', 'boolean'],
            'responsible_id' => ['nullable', 'uuid', 'exists:users,id'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);
        $result = $this->fullCountService->start(
            warehouse: $warehouse,
            user: $request->user(),
            countedAt: $data['counted_at'],
            zone: $data['zone'] ?? null,
            categoryId: $data['category_id'] ?? null,
            notes: $data['notes'] ?? null,
            lockMovements: $request->boolean('lock_movements', true),
            responsibleId: $data['responsible_id'] ?? null,
        );

        return response()->json([
            'data' => $result['count'],
            'summary' => $result['summary'],
        ], 201);
    }

    public function startSpot(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'counted_at' => ['required', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'product_ids' => ['required', 'array', 'min:1'],
            'product_ids.*' => ['uuid', 'exists:products,id'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);
        $result = $this->fullCountService->startSpot(
            warehouse: $warehouse,
            user: $request->user(),
            productIds: $data['product_ids'],
            countedAt: $data['counted_at'],
            notes: $data['notes'] ?? null,
        );

        return response()->json([
            'data' => $result['count'],
            'summary' => $result['summary'],
        ], 201);
    }

    public function saveFullLines(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        $data = $request->validate([
            'lines' => ['required', 'array', 'min:1'],
            'lines.*.id' => ['required', 'uuid'],
            'lines.*.entered_quantity' => ['nullable', 'integer', 'min:0'],
            'lines.*.remainder_ml' => ['nullable', 'integer', 'min:0'],
            'lines.*.sale_unit_id' => ['nullable', 'uuid'],
            'lines.*.variance_reason' => ['nullable', 'string', Rule::in(FullPhysicalCountService::REASONS)],
            'lines.*.notes' => ['nullable', 'string', 'max:500'],
        ]);

        $result = $this->fullCountService->saveLines($inventoryCount, $data['lines'], $request->user());

        return response()->json([
            'data' => $result['count'],
            'summary' => $result['summary'],
        ]);
    }

    public function submitFull(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        $result = $this->fullCountService->submit($inventoryCount, $request->user());

        return response()->json(['data' => $result['count'], 'summary' => $result['summary']]);
    }

    public function reviewFull(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        $result = $this->fullCountService->review($inventoryCount, $request->user());

        return response()->json(['data' => $result['count'], 'summary' => $result['summary']]);
    }

    public function approveFull(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        $result = $this->fullCountService->approve($inventoryCount, $request->user());

        return response()->json(['data' => $result['count'], 'summary' => $result['summary']]);
    }

    public function cancelFull(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        $data = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);
        $result = $this->fullCountService->cancel($inventoryCount, $request->user(), $data['reason'] ?? null);

        return response()->json(['data' => $result['count'], 'summary' => $result['summary']]);
    }

    public function planCycle(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'counted_at' => ['required', 'date'],
            'zone' => ['nullable', 'string', 'max:120'],
            'category_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'inventory_class' => ['nullable', 'string', Rule::in(['A', 'B', 'C'])],
            'product_ids' => ['nullable', 'array'],
            'product_ids.*' => ['uuid', 'exists:products,id'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'responsible_id' => ['nullable', 'uuid', 'exists:users,id'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);
        $result = $this->cycleCountService->plan(
            warehouse: $warehouse,
            user: $request->user(),
            plannedAt: $data['counted_at'],
            zone: $data['zone'] ?? null,
            categoryId: $data['category_id'] ?? null,
            inventoryClass: $data['inventory_class'] ?? null,
            productIds: $data['product_ids'] ?? [],
            notes: $data['notes'] ?? null,
            responsibleId: $data['responsible_id'] ?? null,
        );

        return response()->json(['data' => $result['count'], 'summary' => $result['summary']], 201);
    }

    public function suggestCycle(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'category_id' => ['nullable', 'uuid'],
            'inventory_class' => ['nullable', 'string', Rule::in(['A', 'B', 'C'])],
        ]);
        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);

        return response()->json([
            'data' => $this->cycleCountService->suggest(
                $warehouse,
                $data['category_id'] ?? null,
                $data['inventory_class'] ?? null,
            ),
        ]);
    }

    public function cycleDashboard(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
        ]);
        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);

        return response()->json(['data' => $this->cycleCountService->dashboard($warehouse)]);
    }

    public function generateCycle(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
        ]);
        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);
        $result = $this->cycleCountService->generateDue($warehouse, $request->user());

        return response()->json(['data' => $result]);
    }

    public function startCycle(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        $result = $this->cycleCountService->start($inventoryCount, $request->user());

        return response()->json(['data' => $result['count'], 'summary' => $result['summary']]);
    }

    public function cycleHistory(Product $product): JsonResponse
    {
        return response()->json(['data' => $this->cycleCountService->history($product)]);
    }

    public function saveCycleRules(Request $request): JsonResponse
    {
        $data = $request->validate([
            'rules' => ['required', 'array', 'min:1'],
            'rules.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'rules.*.inventory_class' => ['nullable', 'string', Rule::in(['A', 'B', 'C'])],
            'rules.*.count_frequency' => ['nullable', 'string', Rule::in(['daily', 'weekly', 'monthly', 'quarterly'])],
        ]);

        return response()->json([
            'updated' => $this->cycleCountService->saveRules($data['rules'], $request->user()),
        ]);
    }

    public function confirm(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        return response()->json([
            'data' => $this->countService->confirm($inventoryCount, $request->user()),
        ]);
    }

    public function complete(Request $request, InventoryCount $inventoryCount): JsonResponse
    {
        if ($inventoryCount->count_type === 'cycle') {
            $result = $this->cycleCountService->finalize($inventoryCount, $request->user());

            return response()->json([
                'data' => $result['count'],
                'summary' => $result['summary'],
            ]);
        }

        if (in_array($inventoryCount->count_type, ['full', 'spot'], true)) {
            $result = $this->fullCountService->finalize($inventoryCount, $request->user());

            return response()->json([
                'data' => $result['count'],
                'summary' => $result['summary'],
            ]);
        }

        return response()->json([
            'data' => $this->countService->complete($inventoryCount, $request->user()),
        ]);
    }
}
