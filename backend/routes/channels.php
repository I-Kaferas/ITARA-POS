<?php

use App\Models\User;
use App\Services\Realtime\ChannelAuthorizer;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('tenant.{tenantId}', function (User $user, string $tenantId): bool {
    return app(ChannelAuthorizer::class)->allowsTenant($user, $tenantId);
});

Broadcast::channel('tenant.{tenantId}.store.{storeId}', function (User $user, string $tenantId, string $storeId): bool {
    return app(ChannelAuthorizer::class)->allowsStore($user, $tenantId, $storeId);
});

Broadcast::channel('tenant.{tenantId}.online', function (User $user, string $tenantId): array|bool {
    if (! app(ChannelAuthorizer::class)->allowsTenant($user, $tenantId)) {
        return false;
    }

    return [
        'id' => $user->id,
        'name' => $user->name,
    ];
});
