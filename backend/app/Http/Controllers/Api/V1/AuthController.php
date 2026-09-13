<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AuthToken;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Auth\AuthService;
use App\Services\Auth\AuthTokenService;
use App\Services\Auth\TwoFactorService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Password;

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

    public function pinLogin(Request $request): JsonResponse
    {
        $data = $request->validate([
            'pin' => ['required', 'regex:/^\d{4,6}$/'],
            'device_name' => ['nullable', 'string', 'max:120'],
            'device_id' => ['nullable', 'uuid'],
            'device_identifier' => ['nullable', 'string', 'max:100'],
        ]);

        $tenantHeader = (string) $request->header('X-Tenant-ID', '');
        $tenant = Tenant::query()
            ->where(fn ($query) => $query->where('id', $tenantHeader)->orWhere('slug', $tenantHeader))
            ->first();
        if ($tenant === null) {
            return response()->json(['message' => 'X-Tenant-ID header is required.'], 400);
        }

        return response()->json($this->auth->attemptPinLogin(
            $tenant->id,
            $data['pin'],
            $request,
            $data['device_name'] ?? null,
            $data['device_id'] ?? null,
            $data['device_identifier'] ?? null,
        ));
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

    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user instanceof User, 401);

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:50'],
        ]);

        $user = $this->auth->updateProfile($user, $data);

        return response()->json(['user' => $this->auth->userPayload($user)]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user instanceof User, 401);

        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'confirmed', Password::min(8)],
        ]);

        /** @var AuthToken|null $current */
        $current = $request->attributes->get('auth_token');
        $this->auth->changePassword($user, $data['current_password'], $data['password'], $current?->id);

        return response()->json(['message' => 'Mot de passe modifié.']);
    }
}
