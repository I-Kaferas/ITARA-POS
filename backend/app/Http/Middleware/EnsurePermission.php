<?php

namespace App\Http\Middleware;

use App\Services\Authorization\AuthorizationService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePermission
{
    public function __construct(private AuthorizationService $authorization) {}

    /**
     * @param  string  ...$permissions  Permission slugs (any match grants access)
     */
    public function handle(Request $request, Closure $next, string ...$permissions): Response
    {
        $user = $request->user();

        if ($user === null) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        if ($this->authorization->hasAnyPermission($user, $this->expand($request, $permissions))) {
            return $next($request);
        }

        return response()->json([
            'message' => 'Forbidden. Insufficient permissions.',
            'required_permissions' => $permissions,
        ], 403);
    }

    /**
     * Create / update / delete satisfy the matching manage permission for the HTTP verb.
     *
     * @param  list<string>  $permissions
     * @return list<string>
     */
    private function expand(Request $request, array $permissions): array
    {
        $expanded = $permissions;
        $method = strtoupper($request->method());

        foreach ($permissions as $permission) {
            if (! str_ends_with($permission, '.manage')) {
                continue;
            }

            $base = substr($permission, 0, -strlen('.manage'));

            if ($method === 'POST') {
                $expanded[] = $base.'.create';
                $expanded[] = $base.'.update';
            } elseif (in_array($method, ['PUT', 'PATCH'], true)) {
                $expanded[] = $base.'.update';
            } elseif ($method === 'DELETE') {
                $expanded[] = $base.'.delete';
            }
        }

        return array_values(array_unique($expanded));
    }
}
