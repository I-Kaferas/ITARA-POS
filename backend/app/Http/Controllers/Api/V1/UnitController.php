<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\V1\Concerns\ResolvesStoreIds;
use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Models\Unit;
use App\Services\Catalog\StoreCatalogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class UnitController extends Controller
{
    use ResolvesStoreIds;

    public function __construct(
        private readonly StoreCatalogService $storeCatalogs,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $storeId = $this->resolveStoreId($request);
        if ($storeId) {
            $store = Store::query()->findOrFail($storeId);
            $this->storeCatalogs->ensureUnits($store);
        }

        $query = Unit::query()->orderBy('name');

        if ($storeId) {
            $query->where('store_id', $storeId);
        } elseif ($request->filled('store_id') === false && ! $request->boolean('all_stores')) {
            $query->whereNotNull('store_id');
        }

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $storeIds = $this->resolveStoreIds($request, required: true);

        $data = $request->validate([
            'code' => ['required', 'string', 'max:20'],
            'name' => ['required', 'string', 'max:100'],
            'symbol' => ['nullable', 'string', 'max:20'],
            'is_fractional' => ['boolean'],
            'is_active' => ['boolean'],
            'store_id' => ['nullable', 'uuid'],
            'store_ids' => ['nullable', 'array'],
            'store_ids.*' => ['uuid'],
        ]);

        $created = DB::transaction(function () use ($storeIds, $data) {
            $rows = [];
            foreach ($storeIds as $storeId) {
                $rows[] = Unit::query()->firstOrCreate(
                    [
                        'tenant_id' => app('tenant.id'),
                        'store_id' => $storeId,
                        'code' => $data['code'],
                    ],
                    [
                        'name' => $data['name'],
                        'symbol' => $data['symbol'] ?? null,
                        'is_fractional' => $data['is_fractional'] ?? false,
                        'is_active' => $data['is_active'] ?? true,
                    ],
                );
            }

            return $rows;
        });

        return response()->json([
            'data' => $created[0],
            'created_count' => count($created),
        ], 201);
    }

    public function show(Unit $unit): JsonResponse
    {
        return response()->json(['data' => $unit]);
    }

    public function update(Request $request, Unit $unit): JsonResponse
    {
        $storeIds = $this->targetStoreIds($request, $unit->store_id);
        $data = $this->withoutStoreFields($request->validate([
            'code' => [
                'sometimes',
                'string',
                'max:20',
                Rule::unique('units', 'code')->where(fn ($q) => $q
                    ->where('tenant_id', app('tenant.id'))
                    ->where('store_id', $unit->store_id)
                    ->whereNull('deleted_at'))->ignore($unit->id),
            ],
            'name' => ['sometimes', 'string', 'max:100'],
            'symbol' => ['nullable', 'string', 'max:20'],
            'is_fractional' => ['boolean'],
            'is_active' => ['boolean'],
            'store_id' => ['nullable', 'uuid'],
            'store_ids' => ['nullable', 'array'],
            'store_ids.*' => ['uuid'],
        ]));

        $updated = DB::transaction(function () use ($unit, $storeIds, $data) {
            $originalCode = $unit->code;
            $newCode = $data['code'] ?? $originalCode;
            $rows = [];

            foreach ($storeIds as $storeId) {
                $query = Unit::query()
                    ->where('tenant_id', $unit->tenant_id)
                    ->where('store_id', $storeId);

                $target = $storeId === $unit->store_id
                    ? $unit
                    : ($query->clone()->where('code', $originalCode)->first()
                        ?? $query->clone()->where('code', $newCode)->first());

                if ($target) {
                    $target->update($data);
                    $rows[] = $target->fresh();
                    continue;
                }

                $rows[] = Unit::query()->create([
                    'tenant_id' => $unit->tenant_id,
                    'store_id' => $storeId,
                    'code' => $newCode,
                    'name' => $data['name'] ?? $unit->name,
                    'symbol' => array_key_exists('symbol', $data) ? $data['symbol'] : $unit->symbol,
                    'is_fractional' => $data['is_fractional'] ?? $unit->is_fractional,
                    'is_active' => $data['is_active'] ?? $unit->is_active,
                ]);
            }

            return $rows;
        });

        return response()->json([
            'data' => $unit->fresh(),
            'updated_count' => count($updated),
        ]);
    }

    public function destroy(Unit $unit): JsonResponse
    {
        $unit->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
