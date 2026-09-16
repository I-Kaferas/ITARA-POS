<?php

use App\Models\Store;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('tenant.{tenantId}', function (User $user, string $tenantId): bool {
    if (! $user->is_active) {
        return false;
    }

    if ($user->tenant_id === null) {
        return true;
    }

    return (string) $user->tenant_id === (string) $tenantId;
});

Broadcast::channel('tenant.{tenantId}.store.{storeId}', function (User $user, string $tenantId, string $storeId): bool {
    if (! $user->is_active) {
        return false;
    }

    if ($user->tenant_id !== null && (string) $user->tenant_id !== (string) $tenantId) {
        return false;
    }

    $store = Store::query()->find($storeId);

    return $store !== null && (string) $store->tenant_id === (string) $tenantId;
});
