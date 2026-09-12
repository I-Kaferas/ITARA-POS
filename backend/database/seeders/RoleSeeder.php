<?php

namespace Database\Seeders;

use App\Models\Tenant;
use App\Services\Rbac\RoleProvisioningService;
use Illuminate\Database\Seeder;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $service = app(RoleProvisioningService::class);

        $service->provisionSuperAdminRole();

        Tenant::query()->each(function (Tenant $tenant) use ($service) {
            $service->provisionForTenant($tenant);
        });
    }
}
