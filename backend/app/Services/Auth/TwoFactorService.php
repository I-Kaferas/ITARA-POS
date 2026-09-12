<?php

namespace App\Services\Auth;

use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class TwoFactorService
{
  public function generateSecret(): string
    {
        $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $secret = '';
        for ($i = 0; $i < 16; $i++) {
            $secret .= $chars[random_int(0, 31)];
        }

        return $secret;
    }

    public function getQrCodeUrl(User $user, string $secret): string
    {
        $issuer = rawurlencode(config('app.name', 'POS'));
        $label = rawurlencode($user->email);
        $otpauth = "otpauth://totp/{$issuer}:{$label}?secret={$secret}&issuer={$issuer}&digits=6&period=30";

        return $otpauth;
    }

  public function confirmSetup(User $user, string $code): void
    {
        $secret = $user->two_factor_secret;
        if ($secret === null) {
            throw ValidationException::withMessages([
                'code' => ['Configuration 2FA non initialisée.'],
            ]);
        }

        if (! $this->verifyCode($secret, $code)) {
            throw ValidationException::withMessages([
                'code' => ['Code invalide.'],
            ]);
        }

        $recoveryCodes = collect(range(1, 8))
            ->map(fn () => Str::upper(Str::random(10)))
            ->values()
            ->all();

        $user->forceFill([
            'two_factor_confirmed_at' => now(),
            'two_factor_recovery_codes' => array_map(
                fn (string $plain) => hash('sha256', $plain),
                $recoveryCodes
            ),
        ])->save();

        Cache::put("auth:2fa:recovery:{$user->id}", $recoveryCodes, now()->addMinutes(10));
    }

    /** @return list<string>|null */
    public function pullRecoveryCodes(User $user): ?array
    {
        return Cache::pull("auth:2fa:recovery:{$user->id}");
    }

    public function verify(User $user, string $code): bool
    {
        if ($user->two_factor_secret === null || $user->two_factor_confirmed_at === null) {
            return false;
        }

        if ($this->verifyCode($user->two_factor_secret, $code)) {
            return true;
        }

        return $this->consumeRecoveryCode($user, $code);
    }

    public function createChallenge(User $user): string
    {
        $token = Str::random(64);
        Cache::put(
            $this->challengeKey($token),
            $user->id,
            now()->addMinutes(config('auth_tokens.two_factor_challenge_ttl_minutes'))
        );

        return $token;
    }

    public function resolveChallenge(string $challengeToken): ?User
    {
        $userId = Cache::get($this->challengeKey($challengeToken));
        if ($userId === null) {
            return null;
        }

        return User::query()->find($userId);
    }

    public function forgetChallenge(string $challengeToken): void
    {
        Cache::forget($this->challengeKey($challengeToken));
    }

    public function disable(User $user): void
    {
        $user->forceFill([
            'two_factor_secret' => null,
            'two_factor_confirmed_at' => null,
            'two_factor_recovery_codes' => null,
        ])->save();
    }

    private function verifyCode(string $secret, string $code): bool
    {
        $code = preg_replace('/\s+/', '', $code) ?? '';
        if (! preg_match('/^\d{6}$/', $code)) {
            return false;
        }

        $timeSlice = (int) floor(time() / 30);
        foreach ([-1, 0, 1] as $offset) {
            if (hash_equals($this->generateTotp($secret, $timeSlice + $offset), $code)) {
                return true;
            }
        }

        return false;
    }

    private function consumeRecoveryCode(User $user, string $code): bool
    {
        $codes = $user->two_factor_recovery_codes ?? [];
        $hash = hash('sha256', strtoupper(trim($code)));
        $index = array_search($hash, $codes, true);

        if ($index === false) {
            return false;
        }

        unset($codes[$index]);
        $user->forceFill(['two_factor_recovery_codes' => array_values($codes)])->save();

        return true;
    }

    private function generateTotp(string $secret, int $timeSlice): string
    {
        $key = $this->base32Decode($secret);
        $time = pack('N*', 0, $timeSlice);
        $hash = hash_hmac('sha1', $time, $key, true);
        $offset = ord($hash[19]) & 0x0F;
        $value = (
            ((ord($hash[$offset]) & 0x7F) << 24) |
            ((ord($hash[$offset + 1]) & 0xFF) << 16) |
            ((ord($hash[$offset + 2]) & 0xFF) << 8) |
            (ord($hash[$offset + 3]) & 0xFF)
        ) % 1000000;

        return str_pad((string) $value, 6, '0', STR_PAD_LEFT);
    }

    private function base32Decode(string $secret): string
    {
        $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $secret = strtoupper($secret);
        $buffer = 0;
        $bitsLeft = 0;
        $result = '';

        for ($i = 0, $len = strlen($secret); $i < $len; $i++) {
            $val = strpos($chars, $secret[$i]);
            if ($val === false) {
                continue;
            }
            $buffer = ($buffer << 5) | $val;
            $bitsLeft += 5;
            if ($bitsLeft >= 8) {
                $bitsLeft -= 8;
                $result .= chr(($buffer >> $bitsLeft) & 0xFF);
            }
        }

        return $result;
    }

    private function challengeKey(string $token): string
    {
        return 'auth:2fa:challenge:'.$token;
    }
}
