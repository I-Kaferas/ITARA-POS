<?php

namespace App\Services\BusinessCore;

use App\Enums\LocationType;
use App\Models\Branch;
use App\Models\Location;
use App\Models\Store;
use App\Models\Warehouse;
use App\Tenancy\TenantContext;

class LocationRegistry
{
    public function __construct(private readonly TenantContext $context) {}

    /** @param  array<string, mixed>  $attributes */
    public function create(LocationType $type, array $attributes, ?Location $parent = null): Location
    {
        return Location::query()->create([
            'tenant_id' => $this->context->requireId(),
            'parent_id' => $parent?->id ?? $attributes['parent_id'] ?? null,
            'type' => $type,
            'name' => $attributes['name'],
            'code' => $attributes['code'] ?? null,
            'address' => $attributes['address'] ?? null,
            'geo' => $attributes['geo'] ?? null,
            'metadata' => $attributes['metadata'] ?? null,
            'is_active' => $attributes['is_active'] ?? true,
        ]);
    }

    public function ensureForBranch(Branch $branch): Location
    {
        if ($branch->location_id) {
            $existing = Location::query()->find($branch->location_id);
            if ($existing) {
                return $existing;
            }
        }

        $location = $this->create(LocationType::Branch, [
            'name' => $branch->name,
            'code' => $branch->code,
            'address' => $branch->address,
        ]);

        $branch->location_id = $location->id;
        $branch->save();

        return $location;
    }

    public function ensureForStore(Store $store, ?Location $parent = null): Location
    {
        if ($store->location_id) {
            $existing = Location::query()->find($store->location_id);
            if ($existing) {
                return $existing;
            }
        }

        if (! $parent && $store->branch_id) {
            $branch = Branch::query()->find($store->branch_id);
            if ($branch) {
                $parent = $this->ensureForBranch($branch);
            }
        }

        $location = $this->create(LocationType::Store, [
            'name' => $store->name,
            'code' => $store->code,
            'parent_id' => $parent?->id,
        ], $parent);

        $store->location_id = $location->id;
        $store->save();

        return $location;
    }

    public function ensureForWarehouse(Warehouse $warehouse, ?Location $parent = null): Location
    {
        if ($warehouse->location_id) {
            $existing = Location::query()->find($warehouse->location_id);
            if ($existing) {
                return $existing;
            }
        }

        if (! $parent && $warehouse->branch_id) {
            $branch = Branch::query()->find($warehouse->branch_id);
            if ($branch) {
                $parent = $this->ensureForBranch($branch);
            }
        }

        $location = $this->create(LocationType::Warehouse, [
            'name' => $warehouse->name,
            'code' => $warehouse->code ?? null,
            'parent_id' => $parent?->id,
        ], $parent);

        $warehouse->location_id = $location->id;
        $warehouse->save();

        return $location;
    }
}
