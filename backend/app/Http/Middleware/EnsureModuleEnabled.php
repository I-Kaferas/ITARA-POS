<?php

namespace App\Http\Middleware;

use App\Modules\ModuleManager;
use App\Modules\ModuleRegistry;
use App\Support\ApiError;
use App\Tenancy\TenantContext;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureModuleEnabled
{
    public function __construct(
        private readonly ModuleManager $modules,
        private readonly TenantContext $tenants,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $required = ModuleRegistry::modulesForApiPath($request->path());
        if ($required === []) {
            return $next($request);
        }

        $tenant = $this->tenants->tenant();
        if ($tenant === null) {
            return $next($request);
        }

        if ($this->modules->allowsAny($required, $tenant)) {
            return $next($request);
        }

        return ApiError::json('errors.module_disabled', 403, [
            'module' => $required[0],
        ]);
    }
}
