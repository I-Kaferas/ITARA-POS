<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\StockTransfer;
use App\Models\Warehouse;
use App\Services\Inventory\StockTransferService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StockTransferController extends Controller
{
    public function __construct(
        private readonly StockTransferService $transferService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = StockTransfer::query()
            ->with(['sourceWarehouse:id,name,code', 'destinationWarehouse:id,name,code'])
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function show(StockTransfer $stockTransfer): JsonResponse
    {
        return response()->json([
            'data' => $stockTransfer->load([
                'items.product:id,sku,name',
                'sourceWarehouse',
                'destinationWarehouse',
                'requestedBy:id,name',
                'approvedBy:id,name',
            ]),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'source_warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'destination_warehouse_id' => ['required', 'uuid', 'exists:warehouses,id', 'different:source_warehouse_id'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.batch_id' => ['nullable', 'uuid', 'exists:batches,id'],
        ]);

        $source = Warehouse::query()->findOrFail($data['source_warehouse_id']);
        $destination = Warehouse::query()->findOrFail($data['destination_warehouse_id']);

        $transfer = $this->transferService->create(
            source: $source,
            destination: $destination,
            items: $data['items'],
            requestedBy: $request->user(),
            notes: $data['notes'] ?? null,
        );

        return response()->json(['data' => $transfer], 201);
    }

    public function confirm(Request $request, StockTransfer $stockTransfer): JsonResponse
    {
        return response()->json([
            'data' => $this->transferService->confirm($stockTransfer, $request->user()),
        ]);
    }

    public function approve(Request $request, StockTransfer $stockTransfer): JsonResponse
    {
        return response()->json([
            'data' => $this->transferService->approve($stockTransfer, $request->user()),
        ]);
    }

    public function ship(Request $request, StockTransfer $stockTransfer): JsonResponse
    {
        return response()->json([
            'data' => $this->transferService->ship($stockTransfer, $request->user()),
        ]);
    }

    public function receive(Request $request, StockTransfer $stockTransfer): JsonResponse
    {
        return response()->json([
            'data' => $this->transferService->receive($stockTransfer, $request->user()),
        ]);
    }
}
