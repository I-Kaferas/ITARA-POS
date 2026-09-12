<?php

namespace App\Models\Concerns;

use App\Services\Authorization\AuthorizationService;

trait HasPermissions
{
    public function hasRole(string $roleSlug): bool
    {
        return app(AuthorizationService::class)->hasRole($this, $roleSlug);
    }

    public function hasAnyRole(array $roleSlugs): bool
    {
        return app(AuthorizationService::class)->hasAnyRole($this, $roleSlugs);
    }

    public function hasPermission(string $permission): bool
    {
        return app(AuthorizationService::class)->hasPermission($this, $permission);
    }

    public function hasAnyPermission(array $permissions): bool
    {
        return app(AuthorizationService::class)->hasAnyPermission($this, $permissions);
    }

    public function isSuperAdmin(): bool
    {
        return app(AuthorizationService::class)->isSuperAdmin($this);
    }

    public function getPermissionSlugs(): array
    {
        return app(AuthorizationService::class)->getPermissionSlugs($this);
    }

    public function clearPermissionCache(): void
    {
        app(AuthorizationService::class)->forgetCachedPermissions($this);
    }
}
