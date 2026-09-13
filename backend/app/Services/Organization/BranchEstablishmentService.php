<?php

namespace App\Services\Organization;

use App\Models\Branch;
use App\Models\Company;
use App\Models\Store;
use App\Models\User;
use App\Models\Warehouse;
use Illuminate\Support\Facades\Schema;

class BranchEstablishmentService
{
    /**
     * A company starts with several establishments, each owned by a branch.
     */
    public function ensure(Company $company): Branch
    {
        $branch = Branch::query()->firstOrCreate(
            ['tenant_id' => $company->tenant_id, 'code' => 'HQ'],
            [
                'tenant_id' => $company->tenant_id,
                'company_id' => $company->id,
                'name' => 'Siège',
                'is_active' => true,
                'settings' => [
                    'timezone' => $company->timezone ?: 'Africa/Bujumbura',
                    'receipt_footer' => '',
                ],
            ],
        );

        $this->store($branch, 'Magasin 1', 'MG01', 'store');
        $this->store($branch, 'Magasin 2', 'MG02', 'store');
        $this->store($branch, 'Boutique', 'BT01', 'boutique');

        Warehouse::query()->firstOrCreate(
            ['tenant_id' => $branch->tenant_id, 'code' => 'WH01'],
            [
                'tenant_id' => $branch->tenant_id,
                'branch_id' => $branch->id,
                'name' => 'Entrepôt',
                'is_active' => true,
            ],
        );

        $mainStore = Store::query()->where('branch_id', $branch->id)->where('code', 'MG01')->first();
        if ($mainStore !== null) {
            $mainStore->cashRegisters()->firstOrCreate(
                ['tenant_id' => $branch->tenant_id, 'code' => 'C01'],
                [
                    'tenant_id' => $branch->tenant_id,
                    'name' => 'Caisse 1',
                    'is_active' => true,
                ],
            );

            if (Schema::hasTable('store_user')) {
                $users = User::query()->where('tenant_id', $branch->tenant_id)->where('is_active', true)->pluck('id');
                if ($users->isNotEmpty()) {
                    $mainStore->users()->syncWithoutDetaching($users->all());
                }
            }
        }

        return $branch->fresh(['stores', 'warehouses']);
    }

    private function store(Branch $branch, string $name, string $code, string $kind): Store
    {
        return Store::query()->firstOrCreate(
            ['tenant_id' => $branch->tenant_id, 'code' => $code],
            [
                'tenant_id' => $branch->tenant_id,
                'branch_id' => $branch->id,
                'name' => $name,
                'kind' => $kind,
                'is_active' => true,
            ],
        );
    }
}
