<?php

namespace App\Services\Realtime;

use App\Events\Realtime\RealtimeEvent;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class RealtimePublisher
{
    /**
     * Notify connected clients after the current database transaction commits.
     * Failures are swallowed so the POS HTTP flow never depends on WebSocket.
     */
    public function notify(
        string $type,
        ?string $tenantId,
        ?string $storeId = null,
        ?string $entity = null,
        ?string $id = null,
        ?string $status = null,
    ): void {
        if (! $tenantId) {
            return;
        }

        $payload = array_filter([
            'type' => $type,
            'tenant_id' => $tenantId,
            'store_id' => $storeId,
            'entity' => $entity,
            'id' => $id,
            'status' => $status,
            'occurred_at' => now()->toIso8601String(),
        ], fn ($value) => $value !== null && $value !== '');

        $send = function () use ($payload): void {
            try {
                $driver = (string) config('broadcasting.default', 'null');
                if ($driver === '' || $driver === 'null') {
                    return;
                }

                broadcast(new RealtimeEvent($payload));
            } catch (Throwable $e) {
                Log::debug('Realtime broadcast skipped', [
                    'type' => $payload['type'] ?? null,
                    'error' => $e->getMessage(),
                ]);
            }
        };

        try {
            if (DB::transactionLevel() > 0) {
                DB::afterCommit($send);

                return;
            }

            $send();
        } catch (Throwable $e) {
            Log::debug('Realtime publish skipped', ['error' => $e->getMessage()]);
        }
    }
}
