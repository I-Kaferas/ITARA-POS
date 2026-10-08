<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OfflineTransaction extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'client_uuid',
        'domain',
        'entity_type',
        'entity_id',
        'operation',
        'payload_hash',
        'payload',
        'base_version',
        'status',
        'result',
        'conflict_code',
        'error',
        'attempts',
        'synced_at',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'result' => 'array',
            'attempts' => 'integer',
            'synced_at' => 'datetime',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
