<?php

namespace App\Services\Realtime;

use App\Models\Store;
use App\Models\User;

class ChannelAuthorizer
{
    public function allowsTenant(User $user, string $tenantId): bool
    {
        if (! $user->is_active || $tenantId === '') {
            return false;
        }

        if ($user->tenant_id === null || $user->isSuperAdmin()) {
            return true;
        }

        return (string) $user->tenant_id === $tenantId;
    }

    public function allowsStore(User $user, string $tenantId, string $storeId): bool
    {
        if (! $this->allowsTenant($user, $tenantId) || $storeId === '') {
            return false;
        }

        $store = Store::query()->whereKey($storeId)->first();
        if ($store === null || (string) $store->tenant_id !== $tenantId) {
            return false;
        }

        if ($user->tenant_id === null || $user->isSuperAdmin()) {
            return true;
        }

        if (! $user->stores()->exists()) {
            return true;
        }

        return $user->stores()->whereKey($storeId)->exists();
    }

    /** @return list<string>|null Null means every store of the tenant. */
    public function allowedStoreIds(User $user, string $tenantId): ?array
    {
        if (! $this->allowsTenant($user, $tenantId)) {
            return [];
        }

        if ($user->tenant_id === null || $user->isSuperAdmin() || ! $user->stores()->exists()) {
            return null;
        }

        return $user->stores()->pluck('stores.id')->map(fn ($id) => (string) $id)->all();
    }
}
