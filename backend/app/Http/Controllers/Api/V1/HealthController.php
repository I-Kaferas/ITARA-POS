<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

class HealthController extends Controller
{
    public function health(): JsonResponse
    {
        $reverb = $this->reverbConfigured();

        return response()->json([
            'status' => 'ok',
            'application' => 'ok',
            'service' => 'pos-api',
            'version' => '0.1.0',
            'database' => $this->checkDatabase() ? 'ok' : 'down',
            'redis' => $this->checkRedis() ? 'ok' : 'down',
            'queue' => (string) config('queue.default', 'sync'),
            'reverb' => $reverb ? 'ok' : 'down',
            'realtime' => $reverb ? 'ok' : 'degraded',
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    public function ready(): JsonResponse
    {
        $checks = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
        ];

        $allHealthy = ! in_array(false, $checks, true);

        return response()->json([
            'status' => $allHealthy ? 'ready' : 'degraded',
            'checks' => $checks,
            'timestamp' => now()->toIso8601String(),
        ], $allHealthy ? 200 : 503);
    }

    private function reverbConfigured(): bool
    {
        return config('broadcasting.default') === 'reverb'
            && filled(config('broadcasting.connections.reverb.key'))
            && filled(config('broadcasting.connections.reverb.options.host'));
    }

    private function checkDatabase(): bool
    {
        try {
            DB::connection()->getPdo();

            return true;
        } catch (\Throwable) {
            return false;
        }
    }

    private function checkRedis(): bool
    {
        try {
            if (config('cache.default') === 'redis' || config('queue.default') === 'redis') {
                Redis::ping();

                return true;
            }

            return true;
        } catch (\Throwable) {
            return false;
        }
    }
}
