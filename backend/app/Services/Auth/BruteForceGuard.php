<?php

namespace App\Services\Auth;

use App\Models\LoginAttempt;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\ValidationException;

class BruteForceGuard
{
    public function ensureNotLocked(string $email, ?string $ipAddress): void
    {
        $config = config('auth_tokens.brute_force');
        $lockKey = $this->lockKey($email, $ipAddress);

        if (Cache::has($lockKey)) {
            $minutes = $config['lockout_minutes'];
            throw ValidationException::withMessages([
                'email' => ["Trop de tentatives. Réessayez dans {$minutes} minutes."],
            ])->status(429);
        }
    }

    public function recordFailure(string $email, ?string $ipAddress): void
    {
        LoginAttempt::query()->create([
            'email' => strtolower($email),
            'ip_address' => $ipAddress,
            'successful' => false,
            'attempted_at' => now(),
        ]);

        $config = config('auth_tokens.brute_force');
        $since = now()->subMinutes($config['decay_minutes']);

        $attempts = LoginAttempt::query()
            ->where('email', strtolower($email))
            ->where('successful', false)
            ->where('attempted_at', '>=', $since)
            ->count();

        if ($attempts >= $config['max_attempts']) {
            Cache::put(
                $this->lockKey($email, $ipAddress),
                true,
                now()->addMinutes($config['lockout_minutes'])
            );
        }
    }

    public function recordSuccess(string $email, ?string $ipAddress): void
    {
        LoginAttempt::query()->create([
            'email' => strtolower($email),
            'ip_address' => $ipAddress,
            'successful' => true,
            'attempted_at' => now(),
        ]);

        Cache::forget($this->lockKey($email, $ipAddress));
    }

    private function lockKey(string $email, ?string $ipAddress): string
    {
        return 'auth:lockout:'.hash('sha256', strtolower($email).'|'.($ipAddress ?? ''));
    }
}
