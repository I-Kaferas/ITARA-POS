<?php

namespace App\Console\Commands;

use App\Models\RealtimeOutbox;
use App\Services\Realtime\RealtimePublisher;
use Illuminate\Console\Command;

class FlushRealtimeOutbox extends Command
{
    protected $signature = 'realtime:flush';

    protected $description = 'Broadcast realtime events that were stored but not delivered';

    public function handle(RealtimePublisher $publisher): int
    {
        $minutes = (int) config('realtime.outbox_retry_minutes', 15);

        $pending = RealtimeOutbox::query()
            ->whereNull('broadcast_at')
            ->where('occurred_at', '>=', now()->subMinutes($minutes))
            ->orderBy('occurred_at')
            ->limit(100)
            ->pluck('id');

        foreach ($pending as $eventId) {
            $publisher->broadcastStored((string) $eventId);
        }

        $this->info('Flushed '.$pending->count().' realtime event(s).');

        return self::SUCCESS;
    }
}
