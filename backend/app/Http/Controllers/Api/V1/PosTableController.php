<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\PosTableStatus;
use App\Http\Controllers\Controller;
use App\Models\PosTable;
use App\Models\PosTableZone;
use App\Models\Store;
use App\Services\Pos\PosTableService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PosTableController extends Controller
{
    public function __construct(
        private readonly PosTableService $tables,
    ) {}

    public function index(Store $store): JsonResponse
    {
        $floor = $this->tables->floor($store);

        return response()->json([
            'data' => [
                'zones' => $floor['zones']->map(fn (PosTableZone $zone) => $zone->toArray())->values(),
                'tables' => $floor['tables']->map(fn (PosTable $table) => $table->toFloorArray())->values(),
                'stats' => $floor['stats'],
            ],
        ]);
    }

    public function stats(Store $store): JsonResponse
    {
        return response()->json(['data' => $this->tables->stats($store)]);
    }

    public function store(Request $request, Store $store): JsonResponse
    {
        $table = $this->tables->createTable($store, $this->validatedTable($request));

        return response()->json(['data' => $table->load('zone')->toFloorArray()], 201);
    }

    public function update(Request $request, PosTable $posTable): JsonResponse
    {
        $table = $this->tables->updateTable($posTable, $this->validatedTable($request, updating: true));

        return response()->json(['data' => $table->load('zone')->toFloorArray()]);
    }

    public function destroy(PosTable $posTable): JsonResponse
    {
        $table = $this->tables->deactivate($posTable);

        return response()->json(['data' => $table->toFloorArray()]);
    }

    public function updateStatus(Request $request, PosTable $posTable): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'string', Rule::in(PosTableStatus::values())],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        $table = $this->tables->setStatus($posTable, $data, $request->user());

        return response()->json(['data' => $table->load(['zone', 'currentSale'])->toFloorArray()]);
    }

    public function open(Request $request, Store $store, PosTable $posTable): JsonResponse
    {
        $data = $request->validate([
            'confirm_reserved' => ['sometimes', 'boolean'],
        ]);

        $sale = $this->tables->openOrder(
            $posTable,
            $store,
            $request->user(),
            (bool) ($data['confirm_reserved'] ?? false),
        );

        return response()->json([
            'data' => [
                'table' => $posTable->fresh(['zone', 'currentSale.processedBy', 'currentSale.items'])?->toFloorArray(),
                'sale' => [
                    ...$sale->toSummaryArray(),
                    'items' => $sale->items,
                ],
            ],
        ], 201);
    }

    public function transfer(Request $request, PosTable $posTable): JsonResponse
    {
        $data = $request->validate([
            'to_table_id' => ['required', 'uuid', 'exists:pos_tables,id'],
        ]);

        $destination = PosTable::query()->findOrFail($data['to_table_id']);
        $sale = $this->tables->transfer($posTable, $destination, $request->user());

        return response()->json([
            'data' => [
                'sale' => $sale->toSummaryArray(),
                'from' => $posTable->fresh(['zone'])?->toFloorArray(),
                'to' => $destination->fresh(['zone', 'currentSale'])?->toFloorArray(),
            ],
        ]);
    }

    public function merge(Request $request, PosTable $posTable): JsonResponse
    {
        $data = $request->validate([
            'to_table_id' => ['required', 'uuid', 'exists:pos_tables,id'],
        ]);

        $destination = PosTable::query()->findOrFail($data['to_table_id']);
        $sale = $this->tables->merge($posTable, $destination, $request->user());

        return response()->json([
            'data' => [
                'sale' => [
                    ...$sale->toSummaryArray(),
                    'items' => $sale->items,
                    'merged_sales' => $sale->mergedSales->map->toSummaryArray()->values(),
                ],
                'from' => $posTable->fresh(['zone'])?->toFloorArray(),
                'to' => $destination->fresh(['zone', 'currentSale.items'])?->toFloorArray(),
            ],
        ]);
    }

    public function reserve(Request $request, Store $store, PosTable $posTable): JsonResponse
    {
        $data = $request->validate([
            'guest_name' => ['nullable', 'string', 'max:160', 'required_without:customer_id'],
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'phone' => ['nullable', 'string', 'max:40'],
            'party_size' => ['nullable', 'integer', 'min:1', 'max:200'],
            'reserved_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'status' => ['nullable', 'string', Rule::in(['pending', 'confirmed'])],
        ]);

        $reservation = $this->tables->reserve($posTable, $store, $request->user(), $data);

        return response()->json([
            'data' => [
                'reservation' => $reservation,
                'table' => $posTable->fresh(['zone', 'reservations'])?->toFloorArray(),
            ],
        ], 201);
    }

    public function cancel(Request $request, PosTable $posTable): JsonResponse
    {
        $data = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $sale = $this->tables->cancelOrder($posTable, $request->user(), $data['reason'] ?? null);

        return response()->json([
            'data' => [
                'sale' => $sale->toSummaryArray(),
                'table' => $posTable->fresh(['zone'])?->toFloorArray(),
            ],
        ]);
    }

    public function history(Request $request, PosTable $posTable): JsonResponse
    {
        $filters = $request->validate([
            'limit' => ['sometimes', 'integer', 'min:1', 'max:200'],
            'status' => ['nullable', 'string'],
            'processed_by' => ['nullable', 'uuid'],
            'customer_id' => ['nullable', 'uuid'],
            'min_total' => ['nullable', 'integer', 'min:0'],
            'max_total' => ['nullable', 'integer', 'min:0'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
        ]);

        $history = $this->tables->history($posTable, $filters);

        return response()->json([
            'data' => $history['data']->map->toSummaryArray()->values(),
            'meta' => $history['meta'],
        ]);
    }

    public function zones(Store $store): JsonResponse
    {
        $zones = PosTableZone::query()
            ->where('store_id', $store->id)
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return response()->json(['data' => $zones]);
    }

    public function storeZone(Request $request, Store $store): JsonResponse
    {
        $zone = $this->tables->createZone($store, $this->validatedZone($request));

        return response()->json(['data' => $zone], 201);
    }

    public function updateZone(Request $request, PosTableZone $posTableZone): JsonResponse
    {
        $zone = $this->tables->updateZone($posTableZone, $this->validatedZone($request, updating: true));

        return response()->json(['data' => $zone]);
    }

    public function destroyZone(PosTableZone $posTableZone): JsonResponse
    {
        $this->tables->deleteZone($posTableZone);

        return response()->json(['data' => ['deleted' => true]]);
    }

    /** @return array<string, mixed> */
    private function validatedTable(Request $request, bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:80'],
            'code' => ['nullable', 'string', 'max:40'],
            'capacity' => ['nullable', 'integer', 'min:1', 'max:200'],
            'zone_id' => ['nullable', 'uuid', 'exists:pos_table_zones,id'],
            'description' => ['nullable', 'string', 'max:2000'],
            'is_active' => ['sometimes', 'boolean'],
        ]);
    }

    /** @return array<string, mixed> */
    private function validatedZone(Request $request, bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:80'],
            'description' => ['nullable', 'string', 'max:2000'],
            'sort_order' => ['nullable', 'integer', 'min:0', 'max:999'],
            'is_active' => ['sometimes', 'boolean'],
        ]);
    }
}
