<?php

namespace App\Services\Audit;

use App\Models\AuditLog;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;

class AuditLogService
{
    /**
     * @param  array<string, mixed>|null  $payload
     */
    public function log(
        string $action,
        Model $entity,
        ?string $userId = null,
        ?array $payload = null,
        ?Request $request = null,
    ): AuditLog {
        return AuditLog::query()->create([
            'tenant_id' => $entity->getAttribute('tenant_id'),
            'user_id' => $userId,
            'action' => $action,
            'entity_type' => $entity->getMorphClass(),
            'entity_id' => $entity->getKey(),
            'payload' => $payload,
            'ip_address' => $request?->ip(),
        ]);
    }
}
