<?php

namespace App\Services\Rbac;

use App\Models\Permission;
use App\Models\Role;
use App\Models\Tenant;
use Illuminate\Support\Collection;

class RoleProvisioningService
{
    /**
     * Provision all tenant-scoped roles for a tenant with permissions from config.
     */
    public function provisionForTenant(Tenant $tenant): Collection
    {
        $roles = collect();

        foreach (config('rbac.roles') as $slug => $definition) {
            if ($definition['platform_only'] ?? false) {
                continue;
            }

            $role = Role::query()->firstOrCreate(
                ['tenant_id' => $tenant->id, 'slug' => $slug],
                [
                    'name' => $definition['name'],
                    'is_system' => $definition['is_system'] ?? false,
                ],
            );

            $this->syncRolePermissions($role, $definition['permissions']);

            $roles->put($slug, $role);
        }

        return $roles;
    }

    /**
     * Provision the platform super_admin role (tenant_id = null).
     */
    public function provisionSuperAdminRole(): Role
    {
        $definition = config('rbac.roles.super_admin');

        $role = Role::query()->firstOrCreate(
            ['tenant_id' => null, 'slug' => 'super_admin'],
            [
                'name' => $definition['name'],
                'is_system' => true,
            ],
        );

        $this->syncRolePermissions($role, $definition['permissions']);

        return $role;
    }

    /**
     * @param  array<string>|string  $permissions
     */
    public function syncRolePermissions(Role $role, array|string $permissions): void
    {
        if ($permissions === '*') {
            $role->permissions()->sync(Permission::query()->pluck('id'));

            return;
        }

        $permissionIds = Permission::query()
            ->whereIn('slug', $permissions)
            ->pluck('id');

        $role->permissions()->sync($permissionIds);
    }
}
