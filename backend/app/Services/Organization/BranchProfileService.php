<?php

namespace App\Services\Organization;

use App\Models\Branch;
use App\Models\Sale;
use App\Models\StockBalance;
use App\Models\User;
use Illuminate\Support\Facades\Schema;

class BranchProfileService
{
    /** @return array<string, mixed> */
    public function present(Branch $branch): array
    {
        $branch->load([
            'stores.cashRegisters',
            'warehouses',
            'expenses' => fn ($query) => $query->latest('occurred_on')->limit(20),
        ]);

        $storeIds = $branch->stores->pluck('id');
        $warehouseIds = $branch->warehouses->pluck('id');

        $users = ! Schema::hasTable('store_user')
            ? collect()
            : User::query()
            ->where('tenant_id', $branch->tenant_id)
            ->where(function ($query) use ($branch, $storeIds) {
                $query->whereHas('stores', fn ($stores) => $stores->whereIn('stores.id', $storeIds))
                    ->orWhereHas('roles', fn ($roles) => $roles->where('user_roles.branch_id', $branch->id));
            })
            ->get(['id', 'name', 'email'])
            ->map(fn (User $user) => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ])
            ->values();

        $salesCount = $storeIds->isEmpty() || ! Schema::hasTable('sales')
            ? 0
            : Sale::query()->whereIn('store_id', $storeIds)->count();

        $stockLines = $warehouseIds->isEmpty() || ! Schema::hasTable('stock_balances')
            ? 0
            : StockBalance::query()->whereIn('warehouse_id', $warehouseIds)->count();

        return [
            'id' => $branch->id,
            'company_id' => $branch->company_id,
            'name' => $branch->name,
            'code' => $branch->code,
            'is_active' => $branch->is_active,
            'address' => $branch->address,
            'settings' => $branch->settings ?? [],
            'stores' => $branch->stores->map(fn ($store) => [
                'id' => $store->id,
                'name' => $store->name,
                'code' => $store->code,
                'kind' => $store->kind ?: 'store',
                'is_active' => $store->is_active,
            ])->values(),
            'stock' => [
                'lines' => $stockLines,
                'warehouses' => $branch->warehouses->map(fn ($warehouse) => [
                    'id' => $warehouse->id,
                    'name' => $warehouse->name,
                    'code' => $warehouse->code,
                    'is_active' => $warehouse->is_active,
                ])->values(),
            ],
            'users' => $users,
            'registers' => $branch->stores->flatMap(fn ($store) => $store->cashRegisters->map(fn ($register) => [
                'id' => $register->id,
                'store_id' => $store->id,
                'store_name' => $store->name,
                'name' => $register->name,
                'code' => $register->code,
                'is_active' => $register->is_active,
            ]))->values(),
            'sales_count' => $salesCount,
            'expenses' => $branch->expenses,
        ];
    }
}
