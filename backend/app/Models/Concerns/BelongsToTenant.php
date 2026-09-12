<?php

namespace App\Models\Concerns;

use App\Models\Tenant;
use App\Tenancy\Scopes\TenantScope;
use App\Tenancy\TenantContext;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Validation\ValidationException;

trait BelongsToTenant
{
    public static function bootBelongsToTenant(): void
    {
        static::addGlobalScope(new TenantScope);

        static::creating(function (Model $model): void {
            /** @var TenantContext $context */
            $context = app(TenantContext::class);

            if (! $context->isBound()) {
                return;
            }

            $tenantId = $context->id();

            if ($model->getAttribute('tenant_id') === null) {
                $model->setAttribute('tenant_id', $tenantId);
            }

            if ($model->getAttribute('tenant_id') !== $tenantId) {
                throw ValidationException::withMessages([
                    'tenant_id' => ['Cross-tenant assignment is not allowed.'],
                ]);
            }
        });

        static::updating(function (Model $model): void {
            if ($model->isDirty('tenant_id')) {
                throw ValidationException::withMessages([
                    'tenant_id' => ['Tenant reassignment is not allowed.'],
                ]);
            }
        });
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function scopeForTenant($query, string $tenantId)
    {
        return $query->withoutGlobalScope(TenantScope::class)
            ->where($this->getTable().'.tenant_id', $tenantId);
    }
}
