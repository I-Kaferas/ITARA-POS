<?php

namespace App\Services\Platform;

use App\Models\PlatformAuditLog;
use App\Models\User;

class PlatformAuditLogger
{
    /**
     * @param  array<string, mixed>  $payload
     */
    public function record(?User $actor, string $action, ?string $tenantId, array $payload = [], ?string $ip = null): PlatformAuditLog
    {
        unset($payload['password'], $payload['admin_password']);

        return PlatformAuditLog::query()->create([
            'actor_id' => $actor?->id,
            'tenant_id' => $tenantId,
            'action' => $action,
            'payload' => $payload,
            'ip_address' => $ip,
        ]);
    }
}
