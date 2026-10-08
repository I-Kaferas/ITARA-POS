<?php

namespace App\Http\Middleware;

use App\Models\Tenant;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use App\Support\ApiError;
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
            $user = $request->user();
            $platform = $request->is('api/v1/platform/*') || $request->is('api/v1/auth/me');
            if ($platform && $user instanceof User && app(AuthorizationService::class)->isSuperAdmin($user)) {
                return $next($request);
            }

            return ApiError::json('errors.tenant_required', 400);
        }

        $tenant = Tenant::query()->find($tenantId);

        if (! $tenant) {
            return ApiError::json('errors.tenant_not_found', 404);
        }

        /** @var User|null $user */
        $user = $request->user();
        $superAdmin = $user instanceof User && app(AuthorizationService::class)->isSuperAdmin($user);

        $billingRecovery = $request->is('api/v1/auth/me')
            || $request->is('api/v1/auth/logout')
            || $request->is('api/v1/auth/logout-all')
            || $request->is('api/v1/tenant/subscription')
            || $request->is('api/v1/tenant/subscription/*');

        if (! in_array($tenant->status, ['trial', 'active', 'past_due'], true) && ! $superAdmin && ! ($tenant->status === 'suspended' && $billingRecovery)) {
            return ApiError::json('errors.tenant_inactive', 403);
        }

        if ($user && $user->tenant_id !== null && $user->tenant_id !== $tenant->id) {
            return ApiError::json('errors.tenant_forbidden', 403);
        }

        $this->tenantContext->bind($tenant);

        try {
            return $next($request);
        } finally {
            $this->tenantContext->clear();
        }
    }
}
