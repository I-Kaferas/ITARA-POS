<?php

namespace App\Services\Authorization;

use App\Models\User;
use App\Modules\ModuleManager;
use App\Modules\ModuleRegistry;
use App\Services\Rbac\PermissionCatalog;
use App\Tenancy\TenantCache;

class AuthorizationService
{
    public function isSuperAdmin(User $user): bool
    {
        if ($user->tenant_id !== null) {
            return false;
        }

        return $user->roles()
            ->withoutGlobalScopes()
            ->where('roles.slug', 'super_admin')
            ->whereNull('roles.tenant_id')
            ->exists();
    }

    public function hasRole(User $user, string $roleSlug): bool
    {
        return $user->roles()->where('slug', $roleSlug)->exists();
    }

    public function hasAnyRole(User $user, array $roleSlugs): bool
    {
        return $user->roles()->whereIn('slug', $roleSlugs)->exists();
    }

    public function hasPermission(User $user, string $permission): bool
    {
        if ($this->isSuperAdmin($user)) {
            return true;
        }

        if (! $this->moduleAllows($user, $permission)) {
            return false;
        }

        return $this->matches($permission, $this->getPermissionSlugs($user));
    }

    public function hasAnyPermission(User $user, array $permissions): bool
    {
        if ($this->isSuperAdmin($user)) {
            return true;
        }

        $userPermissions = $this->getPermissionSlugs($user);

        foreach ($permissions as $permission) {
            if ($this->moduleAllows($user, $permission) && $this->matches($permission, $userPermissions)) {
                return true;
            }
        }

        return false;
    }

    public function hasAllPermissions(User $user, array $permissions): bool
    {
        if ($this->isSuperAdmin($user)) {
            return true;
        }

        $userPermissions = $this->getPermissionSlugs($user);

        foreach ($permissions as $permission) {
            if (! $this->moduleAllows($user, $permission) || ! $this->matches($permission, $userPermissions)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @return list<string>
     */
    public function getPermissionSlugs(User $user): array
    {
        return app(TenantCache::class)->remember(
            $this->cacheKey($user),
            config('rbac.permission_cache_ttl', 900),
            fn () => $this->resolvePermissionSlugs($user),
        );
    }

    /**
     * @return list<array{slug: string, name: string, group: string}>
     */
    public function getPermissions(User $user): array
    {
        $user->loadMissing(['roles.permissions']);

        if ($this->isSuperAdmin($user)) {
            return collect(PermissionCatalog::definitions())
                ->map(fn (array $def, string $slug) => [
                    'slug' => $slug,
                    'name' => $def[0],
                    'group' => $def[1],
                ])
                ->values()
                ->all();
        }

        return $user->roles
            ->flatMap(fn ($role) => $role->permissions)
            ->unique('id')
            ->map(fn ($permission) => [
                'slug' => $permission->slug,
                'name' => $permission->name,
                'group' => $permission->group,
            ])
            ->filter(fn (array $permission) => $this->moduleAllows($user, $permission['slug']))
            ->values()
            ->all();
    }

    /**
     * @return list<array{slug: string, name: string, branch_id: ?string, store_id: ?string}>
     */
    public function getRoleAssignments(User $user): array
    {
        $user->loadMissing('roles');

        return $user->roles->map(fn ($role) => [
            'slug' => $role->slug,
            'name' => $role->name,
            'branch_id' => $role->pivot->branch_id,
            'store_id' => $role->pivot->store_id,
        ])->values()->all();
    }

    public function forgetCachedPermissions(User $user): void
    {
        app(TenantCache::class)->forget($this->cacheKey($user));
    }

    /**
     * @return list<string>
     */
    private function resolvePermissionSlugs(User $user): array
    {
        return $user->roles()
            ->with('permissions:id,slug')
            ->get()
            ->flatMap(fn ($role) => $role->permissions->pluck('slug'))
            ->flatMap(fn (string $slug) => $this->equivalents($slug))
            ->unique()
            ->values()
            ->all();
    }

    /** @param  list<string>  $owned */
    private function matches(string $permission, array $owned): bool
    {
        foreach ($this->equivalents($permission) as $candidate) {
            if (in_array($candidate, $owned, true)) {
                return true;
            }
        }

        return false;
    }

    /** @return list<string> */
    private function equivalents(string $permission): array
    {
        $aliases = [
            'sale.create' => 'sales.create',
            'sale.refund' => 'sales.refund',
            'sale.view' => 'sales.view',
            'payment.create' => 'payments.create',
            'receipt.print' => 'receipts.print',
            'stock.adjust' => 'inventory.adjust',
        ];
        $related = [$permission];
        if (isset($aliases[$permission])) {
            $related[] = $aliases[$permission];
        }
        $canonical = array_search($permission, $aliases, true);
        if (is_string($canonical)) {
            $related[] = $canonical;
        }

        return array_values(array_unique($related));
    }

    private function moduleAllows(User $user, string $permission): bool
    {
        $owners = ModuleRegistry::modulesForPermission($permission);
        if ($owners === []) {
            return true;
        }

        return app(ModuleManager::class)->allowsAny($owners, $user->tenant);
    }

    private function cacheKey(User $user): string
    {
        return "user:{$user->id}:permissions";
    }
}
