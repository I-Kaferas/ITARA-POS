<?php

namespace App\Services\Authorization;

use App\Models\User;
use App\Services\Rbac\PermissionCatalog;
use Illuminate\Support\Facades\Cache;

class AuthorizationService
{
    public function isSuperAdmin(User $user): bool
    {
        return $user->tenant_id === null && $this->hasRole($user, 'super_admin');
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

        return $this->matches($permission, $this->getPermissionSlugs($user));
    }

    public function hasAnyPermission(User $user, array $permissions): bool
    {
        if ($this->isSuperAdmin($user)) {
            return true;
        }

        $userPermissions = $this->getPermissionSlugs($user);

        foreach ($permissions as $permission) {
            if ($this->matches($permission, $userPermissions)) {
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
            if (! $this->matches($permission, $userPermissions)) {
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
        return Cache::remember(
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
        Cache::forget($this->cacheKey($user));
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

    private function cacheKey(User $user): string
    {
        return "user:{$user->id}:permissions";
    }
}
