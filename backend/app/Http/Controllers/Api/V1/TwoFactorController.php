<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Auth\AuthService;
use App\Services\Auth\TwoFactorService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class TwoFactorController extends Controller
{
    public function __construct(
        private TwoFactorService $twoFactor,
        private AuthService $auth,
    ) {}

    public function challenge(Request $request): JsonResponse
    {
        $data = $request->validate([
            'challenge_token' => ['required', 'string'],
            'code' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:120'],
        ]);

        $result = $this->auth->completeTwoFactorChallenge(
            $data['challenge_token'],
            $data['code'],
            $request,
        );

        return response()->json($result);
    }

    public function setup(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        if (! $user->isAdministrator()) {
            return response()->json(['message' => '2FA réservé aux administrateurs.'], 403);
        }

        $secret = $this->twoFactor->generateSecret();
        $user->forceFill([
            'two_factor_secret' => $secret,
            'two_factor_confirmed_at' => null,
            'two_factor_recovery_codes' => null,
        ])->save();

        return response()->json([
            'secret' => $secret,
            'qr_code_url' => $this->twoFactor->getQrCodeUrl($user, $secret),
        ]);
    }

    public function confirm(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $data = $request->validate([
            'code' => ['required', 'string'],
        ]);

        $this->twoFactor->confirmSetup($user, $data['code']);
        $recoveryCodes = $this->twoFactor->pullRecoveryCodes($user);

        return response()->json([
            'message' => 'Authentification à deux facteurs activée.',
            'recovery_codes' => $recoveryCodes,
        ]);
    }

    public function disable(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $data = $request->validate([
            'password' => ['required', 'string'],
        ]);

        if (! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'password' => ['Mot de passe incorrect.'],
            ]);
        }

        $this->twoFactor->disable($user);

        return response()->json(['message' => 'Authentification à deux facteurs désactivée.']);
    }

    public function status(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return response()->json([
            'enabled' => $user->hasTwoFactorEnabled(),
            'required_for_role' => $user->isAdministrator(),
        ]);
    }
}
