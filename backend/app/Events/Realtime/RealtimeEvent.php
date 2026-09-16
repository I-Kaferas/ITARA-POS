<?php

namespace App\Events\Realtime;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class RealtimeEvent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public bool $afterCommit = true;

    /**
     * @param  array{
     *     type: string,
     *     tenant_id: string,
     *     store_id?: string|null,
     *     entity?: string|null,
     *     id?: string|null,
     *     status?: string|null,
     *     occurred_at?: string
     * }  $payload
     */
    public function __construct(public array $payload) {}

    /** @return list<PrivateChannel> */
    public function broadcastOn(): array
    {
        $tenantId = $this->payload['tenant_id'] ?? null;
        if (! is_string($tenantId) || $tenantId === '') {
            return [];
        }

        $channels = [new PrivateChannel('tenant.'.$tenantId)];
        $storeId = $this->payload['store_id'] ?? null;
        if (is_string($storeId) && $storeId !== '') {
            $channels[] = new PrivateChannel('tenant.'.$tenantId.'.store.'.$storeId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'domain.changed';
    }

    /** @return array<string, mixed> */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
