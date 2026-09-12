<?php

namespace App\Services\Auth;

use App\Models\AuthToken;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class AuthTokenService
{
    /** @return array{access_token: string, refresh_token: string, auth_token: AuthToken} */
    public function issue(User $user, ?Request $request = null, ?string $deviceName = null): array
    {
        $this->enforceSessionLimit($user);

        $accessToken = $this->generatePlainToken();
        $refreshToken = $this->generatePlainToken();

        $authToken = AuthToken::query()->create([
            'user_id' => $user->id,
            'device_name' => $deviceName ?? $this->resolveDeviceName($request),
            'access_token_hash' => $this->hashToken($accessToken),
            'refresh_token_hash' => $this->hashToken($refreshToken),
            'ip_address' => $request?->ip(),
            'user_agent' => $request?->userAgent(),
            'last_used_at' => now(),
            'access_expires_at' => now()->addMinutes(config('auth_tokens.access_token_ttl_minutes')),
            'refresh_expires_at' => now()->addDays(config('auth_tokens.refresh_token_ttl_days')),
        ]);

        return [
            'access_token' => $accessToken,
            'refresh_token' => $refreshToken,
            'auth_token' => $authToken,
        ];
    }

    public function findByAccessToken(string $plainToken): ?AuthToken
    {
        return AuthToken::query()
            ->where('access_token_hash', $this->hashToken($plainToken))
            ->whereNull('revoked_at')
            ->where('access_expires_at', '>', now())
            ->first();
    }

    public function findByRefreshToken(string $plainToken): ?AuthToken
    {
        return AuthToken::query()
            ->where('refresh_token_hash', $this->hashToken($plainToken))
            ->whereNull('revoked_at')
            ->where('refresh_expires_at', '>', now())
            ->first();
    }

    /** @return array{access_token: string, refresh_token: string, auth_token: AuthToken} */
    public function rotate(AuthToken $authToken, ?Request $request = null): array
    {
        $authToken->revoke();

        return $this->issue($authToken->user, $request, $authToken->device_name);
    }

    public function revokeAllForUser(User $user, ?string $exceptTokenId = null): void
    {
        AuthToken::query()
            ->where('user_id', $user->id)
            ->whereNull('revoked_at')
            ->when($exceptTokenId, fn ($q) => $q->where('id', '!=', $exceptTokenId))
            ->update(['revoked_at' => now()]);
    }

    public function touchLastUsed(AuthToken $authToken): void
    {
        if ($authToken->last_used_at === null || $authToken->last_used_at->diffInMinutes(now()) >= 1) {
            $authToken->update(['last_used_at' => now()]);
        }
    }

    public function hashToken(string $plainToken): string
    {
        return hash('sha256', $plainToken);
    }

    private function generatePlainToken(): string
    {
        return Str::random(80);
    }

    private function enforceSessionLimit(User $user): void
    {
        $max = config('auth_tokens.max_sessions_per_user');
        $active = AuthToken::query()
            ->where('user_id', $user->id)
            ->whereNull('revoked_at')
            ->where('refresh_expires_at', '>', now())
            ->orderBy('last_used_at')
            ->get();

        $overflow = $active->count() - $max + 1;
        if ($overflow > 0) {
            $active->take($overflow)->each->revoke();
        }
    }

    private function resolveDeviceName(?Request $request): ?string
    {
        if ($request === null) {
            return null;
        }

        $ua = $request->userAgent();
        if ($ua === null || $ua === '') {
            return 'Unknown device';
        }

        return Str::limit($ua, 120);
    }
}
