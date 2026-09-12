<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\BatchAllocationStrategy;
use App\Http\Controllers\Controller;
use App\Models\Batch;
use App\Models\Product;
use App\Models\Warehouse;
use App\Services\Inventory\BatchAllocationService;
use App\Services\Inventory\BatchService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class BatchController extends Controller
{
    public function __construct(
        private readonly BatchService $batchService,
        private readonly BatchAllocationService $allocationService,
    ) {}

    public function index(Request $request, Product $product): JsonResponse
    {
        $warehouse = null;

        if ($request->filled('warehouse_id')) {
            $warehouse = Warehouse::query()->findOrFail($request->string('warehouse_id'));
        }

        return response()->json([
            'data' => $this->batchService->listForProduct($product, $warehouse),
            'meta' => [
                'tracks_batches' => $product->tracksBatches(),
                'tracks_expiration' => $product->tracksExpiration(),
                'allocation_strategy' => $product->allocationStrategy()->value,
            ],
        ]);
    }

    public function show(Request $request, Batch $batch): JsonResponse
    {
        $warehouse = $request->filled('warehouse_id')
            ? Warehouse::query()->findOrFail($request->string('warehouse_id'))
            : null;

        return response()->json([
            'data' => $this->batchService->show($batch, $warehouse),
        ]);
    }

    public function store(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'batch_number' => ['required', 'string', 'max:100'],
            'manufactured_at' => ['nullable', 'date'],
            'expires_at' => ['nullable', 'date', 'after_or_equal:manufactured_at'],
            'unit_cost' => ['nullable', 'integer', 'min:0'],
            'quantity' => ['nullable', 'integer', 'min:1'],
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
            'supplier_id' => ['nullable', 'uuid', 'exists:suppliers,id'],
            'metadata' => ['nullable', 'array'],
        ]);

        if (! empty($data['quantity']) && ! empty($data['warehouse_id'])) {
            $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);

            $batch = $this->batchService->receiveStock($warehouse, $product, [
                'batch_number' => $data['batch_number'],
                'quantity' => $data['quantity'],
                'manufactured_at' => $data['manufactured_at'] ?? null,
                'expires_at' => $data['expires_at'] ?? null,
                'unit_cost' => $data['unit_cost'] ?? null,
                'supplier_id' => $data['supplier_id'] ?? null,
                'metadata' => $data['metadata'] ?? null,
                'performed_by' => $request->user()?->id,
            ]);

            return response()->json([
                'data' => $this->batchService->show($batch, $warehouse),
            ], 201);
        }

        $batch = Batch::query()->create([
            'tenant_id' => $product->tenant_id,
            'product_id' => $product->id,
            'batch_number' => $data['batch_number'],
            'manufactured_at' => $data['manufactured_at'] ?? null,
            'expires_at' => $data['expires_at'] ?? null,
            'unit_cost' => $data['unit_cost'] ?? null,
            'supplier_id' => $data['supplier_id'] ?? null,
            'metadata' => $data['metadata'] ?? null,
            'received_at' => now(),
        ]);

        return response()->json(['data' => $batch], 201);
    }

    public function receive(Request $request, Batch $batch): JsonResponse
    {
        $batch->load('product');

        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'quantity' => ['required', 'integer', 'min:1'],
            'unit_cost' => ['nullable', 'integer', 'min:0'],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);

        $updated = $this->batchService->receiveStock($warehouse, $batch->product, [
            'batch_number' => $batch->batch_number,
            'quantity' => $data['quantity'],
            'manufactured_at' => $batch->manufactured_at?->toDateString(),
            'expires_at' => $batch->expires_at?->toDateString(),
            'unit_cost' => $data['unit_cost'] ?? $batch->unit_cost,
            'supplier_id' => $batch->supplier_id,
            'performed_by' => $request->user()?->id,
            'notes' => $data['notes'] ?? null,
        ]);

        return response()->json([
            'data' => $this->batchService->show($updated, $warehouse),
        ]);
    }

    public function previewAllocation(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'quantity' => ['required', 'integer', 'min:1'],
            'strategy' => ['nullable', Rule::in(BatchAllocationStrategy::values())],
            'product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);
        $strategy = isset($data['strategy'])
            ? BatchAllocationStrategy::from($data['strategy'])
            : null;

        return response()->json([
            'data' => $this->allocationService->preview(
                warehouse: $warehouse,
                product: $product,
                quantity: $data['quantity'],
                productVariantId: $data['product_variant_id'] ?? null,
                strategy: $strategy,
            ),
            'meta' => [
                'strategy' => ($strategy ?? $product->allocationStrategy())->value,
            ],
        ]);
    }
}
