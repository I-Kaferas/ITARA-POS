<?php

namespace App\Services\Auth;

use App\Models\Device;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthService
{
    public function __construct(
        private AuthTokenService $tokens,
        private BruteForceGuard $bruteForce,
        private TwoFactorService $twoFactor,
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function attemptLogin(string $email, string $password, ?Request $request = null, ?string $deviceName = null): array
    {
        $ip = $request?->ip();
        $this->bruteForce->ensureNotLocked($email, $ip);

        $user = User::query()->where('email', $email)->first();

        if (! $user || ! Hash::check($password, $user->password)) {
            $this->bruteForce->recordFailure($email, $ip);
            throw ValidationException::withMessages([
                'email' => ['Identifiants invalides.'],
            ]);
        }

        if (! $user->is_active) {
            throw ValidationException::withMessages([
                'email' => ['Compte désactivé.'],
            ]);
        }

        $this->bruteForce->recordSuccess($email, $ip);

        if ($user->requiresTwoFactorChallenge()) {
            return [
                'requires_two_factor' => true,
                'challenge_token' => $this->twoFactor->createChallenge($user),
            ];
        }

        return $this->tokenResponse($user, $request, $deviceName);
    }

    /**
     * PIN login for an authorized terminal. Permissions are included so the client can keep working offline.
     *
     * @return array<string, mixed>
     */
    public function attemptPinLogin(
        string $tenantId,
        string $pin,
        ?Request $request = null,
        ?string $deviceName = null,
        ?string $deviceId = null,
        ?string $deviceIdentifier = null,
    ): array {
        $ip = $request?->ip();
        $subject = 'pin:'.$tenantId;
        $this->bruteForce->ensureNotLocked($subject, $ip, 'pin');

        $user = User::query()
            ->where('tenant_id', $tenantId)
            ->where('pin', $pin)
            ->first();

        if (! $user || ! $user->is_active) {
            $this->bruteForce->recordFailure($subject, $ip);
            throw ValidationException::withMessages([
                'pin' => ['PIN invalide.'],
            ]);
        }

        $this->assertAuthorizedDevice($tenantId, $deviceId, $deviceIdentifier);
        $this->bruteForce->recordSuccess($subject, $ip);

        return $this->tokenResponse($user, $request, $deviceName);
    }

    public function changePassword(User $user, string $currentPassword, string $newPassword, ?string $exceptTokenId = null): void
    {
        if (! Hash::check($currentPassword, $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['Mot de passe actuel incorrect.'],
            ]);
        }

        $user->forceFill(['password' => $newPassword])->save();
        $this->tokens->revokeAllForUser($user, $exceptTokenId);
    }

    /**
     * @param  array{name?: string, phone?: ?string}  $data
     */
    public function updateProfile(User $user, array $data): User
    {
        $user->fill([
            'name' => $data['name'] ?? $user->name,
            'phone' => array_key_exists('phone', $data) ? $data['phone'] : $user->phone,
        ])->save();

        return $user->fresh() ?? $user;
    }

    private function assertAuthorizedDevice(string $tenantId, ?string $deviceId, ?string $identifier): void
    {
        if (($deviceId === null || $deviceId === '') && ($identifier === null || $identifier === '')) {
            return;
        }

        $device = Device::query()
            ->where('tenant_id', $tenantId)
            ->when($deviceId, fn ($query) => $query->whereKey($deviceId))
            ->when(! $deviceId && $identifier, fn ($query) => $query->where('identifier', $identifier))
            ->first();

        if (! $device || $device->isRevoked() || $device->registration_status !== 'registered') {
            throw ValidationException::withMessages([
                'device_id' => ['Appareil non autorisé.'],
            ]);
        }

        $device->forceFill(['last_sync_at' => now()])->save();
    }

    /**
     * @return array<string, mixed>
     */
    public function completeTwoFactorChallenge(string $challengeToken, string $code, ?Request $request = null): array
    {
        $user = $this->twoFactor->resolveChallenge($challengeToken);

        if ($user === null) {
            throw ValidationException::withMessages([
                'challenge_token' => ['Session 2FA expirée. Reconnectez-vous.'],
            ]);
        }

        if (! $this->twoFactor->verify($user, $code)) {
            throw ValidationException::withMessages([
                'code' => ['Code 2FA invalide.'],
            ]);
        }

        $this->twoFactor->forgetChallenge($challengeToken);

        return $this->tokenResponse($user, $request);
    }

    /**
     * @return array<string, mixed>
     */
    public function refresh(string $refreshToken, ?Request $request = null): array
    {
        $authToken = $this->tokens->findByRefreshToken($refreshToken);

        if ($authToken === null) {
            throw ValidationException::withMessages([
                'refresh_token' => ['Jeton de rafraîchissement invalide ou expiré.'],
            ]);
        }

        $rotated = $this->tokens->rotate($authToken, $request);

        return $this->formatTokenPayload($rotated['access_token'], $rotated['refresh_token'], $authToken->user);
    }

    /**
     * @return array<string, mixed>
     */
    private function tokenResponse(User $user, ?Request $request = null, ?string $deviceName = null): array
    {
        $issued = $this->tokens->issue($user, $request, $deviceName);

        return $this->formatTokenPayload($issued['access_token'], $issued['refresh_token'], $user);
    }

    /**
     * @return array<string, mixed>
     */
    private function formatTokenPayload(string $accessToken, string $refreshToken, User $user): array
    {
        return [
            'access_token' => $accessToken,
            'refresh_token' => $refreshToken,
            'token_type' => 'Bearer',
            'expires_in' => config('auth_tokens.access_token_ttl_minutes') * 60,
            'user' => $this->userPayload($user),
        ];
    }

    /** @return array<string, mixed> */
    public function userPayload(User $user): array
    {
        $authorization = app(AuthorizationService::class);
        $catalog = app(\App\Services\Platform\SaasCatalog::class);
        $superAdmin = $authorization->isSuperAdmin($user);

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'tenant_id' => $user->tenant_id,
            'is_super_admin' => $superAdmin,
            'modules' => $superAdmin ? \App\Services\Platform\SaasCatalog::MODULES : $catalog->modules($user->tenant_id ? $user->tenant : null),
            'email_verified' => $user->hasVerifiedEmail(),
            'phone_verified' => $user->phone_verified_at !== null,
            'two_factor_enabled' => $user->hasTwoFactorEnabled(),
            'roles' => collect($authorization->getRoleAssignments($user))->pluck('slug')->values()->all(),
            'role_assignments' => $authorization->getRoleAssignments($user),
            'permissions' => collect($authorization->getPermissions($user))->pluck('slug')->values()->all(),
        ];
    }
}
