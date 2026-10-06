<?php

namespace App\Services\Realtime;

use App\Events\Realtime\RealtimeEvent;
use App\Models\RealtimeOutbox;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class RealtimePublisher
{
    /**
     * Persist the event in the current transaction, then broadcast only after commit.
     * The database remains the source of truth. The socket only propagates the change.
     *
     * @param  array<string, mixed>  $data
     */
    public function notify(
        string $type,
        ?string $tenantId,
        ?string $storeId = null,
        ?string $entity = null,
        ?string $id = null,
        ?string $status = null,
        array $data = [],
    ): void {
        if (! $tenantId || $type === '') {
            return;
        }

        $eventId = (string) Str::uuid();
        $row = [
            'id' => $eventId,
            'tenant_id' => $tenantId,
            'store_id' => $storeId ?: null,
            'user_id' => auth()->id(),
            'event_name' => $type,
            'entity_type' => $entity,
            'entity_id' => $id,
            'status' => $status,
            'payload' => $this->safeData($data),
            'occurred_at' => now(),
        ];

        $persist = function () use ($row): void {
            RealtimeOutbox::query()->create($row);
        };

        $broadcast = function () use ($eventId): void {
            $this->dispatchBroadcast($eventId);
        };

        try {
            if (DB::transactionLevel() > 0) {
                $persist();
                DB::afterCommit($broadcast);

                return;
            }

            DB::transaction(function () use ($persist, $broadcast): void {
                $persist();
                DB::afterCommit($broadcast);
            });
        } catch (Throwable $e) {
            Log::warning('realtime.publish_failed', [
                'event_id' => $eventId,
                'type' => $type,
                'tenant_id' => $tenantId,
                'error' => $e->getMessage(),
            ]);
        }
    }

    public function dispatchBroadcast(string $eventId): void
    {
        $send = function () use ($eventId): void {
            $this->broadcastStored($eventId);
        };

        if (app()->runningUnitTests()) {
            $send();

            return;
        }

        dispatch($send)
            ->afterResponse()
            ->onQueue((string) config('realtime.queue', 'default'));
    }

    public function broadcastStored(string $eventId): void
    {
        $stored = RealtimeOutbox::query()->find($eventId);
        if ($stored === null) {
            return;
        }

        $driver = (string) config('broadcasting.default', 'null');
        if ($driver === '' || $driver === 'null') {
            return;
        }

        try {
            broadcast(new RealtimeEvent($stored->envelope()));
            $stored->forceFill(['broadcast_at' => now()])->save();
        } catch (Throwable $e) {
            Log::warning('realtime.broadcast_failed', [
                'event_id' => $eventId,
                'type' => $stored->event_name,
                'tenant_id' => $stored->tenant_id,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /** @param  array<string, mixed>  $data */
    private function safeData(array $data): array
    {
        $blocked = ['password', 'pin', 'token', 'api_token', 'secret', 'two_factor_secret', 'two_factor_recovery_codes'];

        return array_filter(
            $data,
            fn ($value, $key) => ! in_array($key, $blocked, true) && $value !== null,
            ARRAY_FILTER_USE_BOTH,
        );
    }
}
