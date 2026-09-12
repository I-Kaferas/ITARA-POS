<?php

namespace App\Services\Auth;

use App\Models\PhoneVerificationCode;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class PhoneVerificationService
{
    public function sendCode(User $user, string $phone): string
    {
        $code = (string) random_int(100000, 999999);

        PhoneVerificationCode::query()
            ->where('user_id', $user->id)
            ->whereNull('verified_at')
            ->delete();

        PhoneVerificationCode::query()->create([
            'user_id' => $user->id,
            'phone' => $phone,
            'code_hash' => hash('sha256', $code),
            'expires_at' => now()->addMinutes(config('auth_tokens.phone_code_ttl_minutes')),
        ]);

        $user->update(['phone' => $phone]);

        Log::info('Phone verification code generated', [
            'user_id' => $user->id,
            'phone' => $phone,
            'code' => app()->environment('production') ? '[redacted]' : $code,
        ]);

        return $code;
    }

    public function verify(User $user, string $code): void
    {
        $record = PhoneVerificationCode::query()
            ->where('user_id', $user->id)
            ->whereNull('verified_at')
            ->latest()
            ->first();

        if ($record === null || $record->isExpired()) {
            throw ValidationException::withMessages([
                'code' => ['Code expiré ou introuvable.'],
            ]);
        }

        if (! hash_equals($record->code_hash, hash('sha256', $code))) {
            throw ValidationException::withMessages([
                'code' => ['Code invalide.'],
            ]);
        }

        $record->update(['verified_at' => now()]);
        $user->forceFill([
            'phone' => $record->phone,
            'phone_verified_at' => now(),
        ])->save();
    }
}
