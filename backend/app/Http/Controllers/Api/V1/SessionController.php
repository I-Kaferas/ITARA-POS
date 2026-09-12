<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AuthToken;
use App\Services\Auth\AuthTokenService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SessionController extends Controller
{
    public function __construct(private AuthTokenService $tokens) {}

    public function index(Request $request): JsonResponse
    {
        /** @var AuthToken|null $current */
        $current = $request->attributes->get('auth_token');

        $sessions = AuthToken::query()
            ->where('user_id', $request->user()->id)
            ->whereNull('revoked_at')
            ->where('refresh_expires_at', '>', now())
            ->orderByDesc('last_used_at')
            ->get()
            ->map(fn (AuthToken $token) => [
                'id' => $token->id,
                'device_name' => $token->device_name,
                'ip_address' => $token->ip_address,
                'last_used_at' => $token->last_used_at?->toIso8601String(),
                'created_at' => $token->created_at?->toIso8601String(),
                'is_current' => $current !== null && $current->id === $token->id,
            ]);

        return response()->json(['data' => $sessions]);
    }

    public function destroy(Request $request, AuthToken $session): JsonResponse
    {
        if ($session->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Session introuvable.'], 404);
        }

        $session->revoke();

        return response()->json(['message' => 'Session révoquée.']);
    }

    public function destroyOthers(Request $request): JsonResponse
    {
        /** @var AuthToken|null $current */
        $current = $request->attributes->get('auth_token');

        $this->tokens->revokeAllForUser($request->user(), $current?->id);

        return response()->json(['message' => 'Autres sessions révoquées.']);
    }
}
