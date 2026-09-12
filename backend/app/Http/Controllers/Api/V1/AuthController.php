<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AuthToken;
use App\Models\User;
use App\Services\Auth\AuthService;
use App\Services\Auth\AuthTokenService;
use App\Services\Auth\TwoFactorService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(
        private AuthService $auth,
        private AuthTokenService $tokens,
    ) {}

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:120'],
        ]);

        $result = $this->auth->attemptLogin(
            $data['email'],
            $data['password'],
            $request,
            $data['device_name'] ?? null,
        );

        return response()->json($result);
    }

    public function refresh(Request $request): JsonResponse
    {
        $data = $request->validate([
            'refresh_token' => ['required', 'string'],
        ]);

        return response()->json($this->auth->refresh($data['refresh_token'], $request));
    }

    public function logout(Request $request): JsonResponse
    {
        /** @var AuthToken|null $authToken */
        $authToken = $request->attributes->get('auth_token');
        $authToken?->revoke();

        return response()->json(['message' => 'Déconnexion réussie.']);
    }

    public function logoutAll(Request $request): JsonResponse
    {
        $user = $request->user();
        /** @var AuthToken|null $current */
        $current = $request->attributes->get('auth_token');

        if ($user instanceof User) {
            $this->tokens->revokeAllForUser($user, $current?->id);
        }

        return response()->json(['message' => 'Toutes les sessions ont été révoquées.']);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $this->auth->userPayload($request->user()),
        ]);
    }
}
