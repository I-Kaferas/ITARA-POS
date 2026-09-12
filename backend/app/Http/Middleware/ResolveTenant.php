<?php

namespace App\Http\Middleware;

use App\Models\Tenant;
use App\Models\User;
use App\Tenancy\TenantContext;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ResolveTenant
{
    public function __construct(private TenantContext $tenantContext) {}

    public function handle(Request $request, Closure $next): Response
    {
        $tenantId = $request->header('X-Tenant-ID');

        if (! $tenantId) {
            return response()->json(['message' => 'X-Tenant-ID header is required.'], 400);
        }

        $tenant = Tenant::query()->find($tenantId);

        if (! $tenant) {
            return response()->json(['message' => 'Tenant not found.'], 404);
        }

        if ($tenant->status !== 'active') {
            return response()->json(['message' => 'Tenant is not active.'], 403);
        }

        /** @var User|null $user */
        $user = $request->user();

        if ($user && $user->tenant_id !== null && $user->tenant_id !== $tenant->id) {
            return response()->json(['message' => 'Forbidden tenant access.'], 403);
        }

        $this->tenantContext->bind($tenant);

        return $next($request);
    }
}
