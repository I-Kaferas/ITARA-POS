<?php

namespace App\Tenancy;

use App\Models\Tenant;

class BindTenant
{
    public function handle(object $job, callable $next): mixed
    {
        $context = app(TenantContext::class);
        $previous = $context->tenant();
        $tenantId = $job->tenantId ?? null;

        if (is_string($tenantId) && $tenantId !== '') {
            $tenant = Tenant::query()->find($tenantId);
            if ($tenant) {
                $context->bind($tenant);
            }
        }

        try {
            return $next($job);
        } finally {
            if ($previous) {
                $context->bind($previous);
            } else {
                $context->clear();
            }
        }
    }
}
