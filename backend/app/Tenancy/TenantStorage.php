<?php

namespace App\Tenancy;

use RuntimeException;

class TenantStorage
{
    public function __construct(private readonly TenantContext $context) {}

    public function path(string $relative): string
    {
        $tenantId = $this->context->requireId();
        $relative = ltrim($relative, '/');

        if ($this->belongsTo($relative, $tenantId)) {
            return $relative;
        }

        return 'tenants/'.$tenantId.'/'.$relative;
    }

    public function assertOwned(string $path, ?string $tenantId = null): void
    {
        $owner = $tenantId ?? $this->context->requireId();
        if (! $this->belongsTo(ltrim($path, '/'), $owner)) {
            throw new RuntimeException('File is outside the tenant directory.');
        }
    }

    private function belongsTo(string $path, string $tenantId): bool
    {
        return str_starts_with($path, $tenantId.'/')
            || str_starts_with($path, 'tenants/'.$tenantId.'/');
    }
}
