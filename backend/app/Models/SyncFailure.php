<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class SyncFailure extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'entity_type',
        'entity_id',
        'error',
        'occurred_at',
        'resolved_at',
    ];

    protected function casts(): array
    {
        return [
            'occurred_at' => 'datetime',
            'resolved_at' => 'datetime',
        ];
    }

    public static function record(string $tenantId, ?string $storeId, string $entityType, string $entityId, string $error): void
    {
        static::query()->updateOrCreate(
            [
                'tenant_id' => $tenantId,
                'entity_type' => $entityType,
                'entity_id' => $entityId,
            ],
            [
                'store_id' => $storeId,
                'error' => mb_substr($error, 0, 500),
                'occurred_at' => now(),
                'resolved_at' => null,
            ],
        );
    }

    public static function resolve(string $tenantId, string $entityType, string $entityId): void
    {
        static::query()
            ->where('tenant_id', $tenantId)
            ->where('entity_type', $entityType)
            ->where('entity_id', $entityId)
            ->whereNull('resolved_at')
            ->update(['resolved_at' => now()]);
    }
}
