<?php

namespace App\Services\Inventory;

use App\Models\Store;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;

/**
 * Stock lives on the store. The warehouse row is the ledger key for that store,
 * kept in sync with the store name and code so the user never manages a depot.
 */
class StoreStockLocation
{
    public function attachAll(): void
    {
        Store::query()
            ->orderByDesc('is_main')
            ->orderBy('created_at')
            ->orderBy('id')
            ->each(function (Store $store): void {
                $this->forStore($store);
            });
    }

    public function forStore(Store $store): Warehouse
    {
        $linked = Warehouse::query()->where('store_id', $store->id)->first();
        if ($linked !== null) {
            $this->syncIdentity($linked, $store);

            return $linked->fresh() ?? $linked;
        }

        return DB::transaction(function () use ($store): Warehouse {
            $linked = Warehouse::query()->where('store_id', $store->id)->lockForUpdate()->first();
            if ($linked !== null) {
                $this->syncIdentity($linked, $store);

                return $linked->fresh() ?? $linked;
            }

            $claim = $this->claimableUnassigned($store);
            if ($claim !== null) {
                $claim->store_id = $store->id;
                $this->syncIdentity($claim, $store);

                return $claim->fresh() ?? $claim;
            }

            return Warehouse::query()->create([
                'tenant_id' => $store->tenant_id,
                'branch_id' => $store->branch_id,
                'store_id' => $store->id,
                'name' => $store->name,
                'code' => $this->availableCode($store),
                'is_active' => (bool) $store->is_active,
            ]);
        });
    }

    private function claimableUnassigned(Store $store): ?Warehouse
    {
        $unassigned = Warehouse::query()
            ->where('branch_id', $store->branch_id)
            ->whereNull('store_id')
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();

        if ($unassigned->isEmpty()) {
            return null;
        }

        $stores = Store::query()
            ->where('branch_id', $store->branch_id)
            ->orderByDesc('is_main')
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();

        if ($stores->count() === 1) {
            return $unassigned->first();
        }

        $main = $stores->first(fn (Store $candidate) => (bool) $candidate->is_main) ?? $stores->first();

        return $unassigned->count() === 1 && $main?->id === $store->id
            ? $unassigned->first()
            : null;
    }

    private function syncIdentity(Warehouse $warehouse, Store $store): void
    {
        $warehouse->name = $store->name;
        $warehouse->branch_id = $store->branch_id;
        $warehouse->is_active = (bool) $store->is_active;
        $warehouse->code = $this->availableCode($store, $warehouse->id);

        if ($warehouse->isDirty()) {
            $warehouse->save();
        }
    }

    private function availableCode(Store $store, ?string $ignoreWarehouseId = null): string
    {
        $base = trim((string) $store->code);
        if ($base === '') {
            $base = 'ST';
        }
        $base = substr($base, 0, 50);
        $candidate = $base;
        $suffix = 2;

        while ($this->codeTaken($store->tenant_id, $candidate, $ignoreWarehouseId)) {
            $tail = '-'.$suffix;
            $candidate = substr($base, 0, 50 - strlen($tail)).$tail;
            $suffix++;
        }

        return $candidate;
    }

    private function codeTaken(string $tenantId, string $code, ?string $ignoreWarehouseId): bool
    {
        return Warehouse::withTrashed()
            ->where('tenant_id', $tenantId)
            ->where('code', $code)
            ->when($ignoreWarehouseId, fn ($query) => $query->where('id', '!=', $ignoreWarehouseId))
            ->exists();
    }
}
