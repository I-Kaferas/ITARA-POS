<?php

namespace App\Tenancy;

use App\Models\Tenant;
use RuntimeException;

class TenantContext
{
    public function bind(Tenant $tenant): void
    {
        app()->instance('tenant', $tenant);
        app()->instance('tenant.id', $tenant->id);
    }

    public function clear(): void
    {
        app()->forgetInstance('tenant');
        app()->forgetInstance('tenant.id');
    }

    public function isBound(): bool
    {
        return app()->bound('tenant.id');
    }

    public function id(): ?string
    {
        return app()->bound('tenant.id') ? app('tenant.id') : null;
    }

    public function tenant(): ?Tenant
    {
        return app()->bound('tenant') ? app('tenant') : null;
    }

    public function requireId(): string
    {
        $id = $this->id();

        if ($id === null) {
            throw new RuntimeException('Tenant context is not bound.');
        }

        return $id;
    }

    /**
     * @template TReturn
     *
     * @param  callable(): TReturn  $callback
     * @return TReturn
     */
    public function runWithoutScope(callable $callback)
    {
        $tenant = $this->tenant();
        $tenantId = $this->id();

        $this->clear();

        try {
            return $callback();
        } finally {
            if ($tenant !== null && $tenantId !== null) {
                $this->bind($tenant);
            }
        }
    }
}
