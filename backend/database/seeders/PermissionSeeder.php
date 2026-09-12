<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Services\Rbac\PermissionCatalog;
use Illuminate\Database\Seeder;

class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        foreach (PermissionCatalog::definitions() as $slug => [$name, $group]) {
            Permission::query()->firstOrCreate(
                ['slug' => $slug],
                [
                    'name' => $name,
                    'group' => $group,
                ],
            );
        }
    }
}
