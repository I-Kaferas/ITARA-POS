<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class RealtimeOutbox extends Model
{
    use HasUuids;

    protected $table = 'realtime_outbox';

    protected $fillable = [
        'tenant_id',
        'store_id',
        'user_id',
        'event_name',
        'entity_type',
        'entity_id',
        'status',
        'payload',
        'occurred_at',
        'broadcast_at',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'occurred_at' => 'datetime',
            'broadcast_at' => 'datetime',
        ];
    }

    /** @return array<string, mixed> */
    public function envelope(): array
    {
        $payload = is_array($this->payload) ? $this->payload : [];

        return array_filter([
            'event_id' => $this->id,
            'type' => $this->event_name,
            'event_name' => $this->event_name,
            'occurred_at' => optional($this->occurred_at)->toIso8601String(),
            'tenant_id' => $this->tenant_id,
            'store_id' => $this->store_id,
            'user_id' => $this->user_id,
            'entity' => $this->entity_type,
            'entity_id' => $this->entity_id,
            'id' => $this->entity_id,
            'status' => $this->status,
            'data' => $payload,
        ], fn ($value) => $value !== null && $value !== '' && $value !== []);
    }
}
