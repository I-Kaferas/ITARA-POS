<?php

namespace App\Http\Middleware;

use App\Models\AuthToken;
use App\Services\Auth\AuthTokenService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateApiToken
{
    public function __construct(private AuthTokenService $tokens) {}

    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();

        if (! $token) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $authToken = $this->tokens->findByAccessToken($token);

        if ($authToken === null) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $user = $authToken->user;

        if (! $user || ! $user->is_active) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $this->tokens->touchLastUsed($authToken);

        auth()->setUser($user);
        $request->setUserResolver(fn () => $user);
        $request->attributes->set('auth_token', $authToken);

        return $next($request);
    }
}
