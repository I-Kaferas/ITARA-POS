<?php

namespace App\Services\Platform;

use App\Models\SaasPlan;
use App\Models\SaasSubscription;
use App\Models\Tenant;
use Illuminate\Validation\ValidationException;

class SaasLimitGuard
{
    public function __construct(private readonly SaasUsageMeter $usage) {}

    public function assertWithin(Tenant $tenant, string $resource): void
    {
        $subscription = SaasSubscription::query()->where('tenant_id', $tenant->id)->first();
        if ($subscription === null || $subscription->status === 'cancelled') {
            return;
        }

        $plan = SaasPlan::query()->where('code', $subscription->plan_code)->first();
        $limit = $plan?->limit($resource);
        if ($plan === null || $limit === null) {
            return;
        }

        $used = $this->usage->snapshot($tenant, $subscription)[$resource] ?? 0;
        if ($used >= $limit) {
            throw ValidationException::withMessages([
                $resource => ['saas.limit_'.$this->code($resource)],
            ]);
        }
    }

    public function assertStorage(Tenant $tenant, int $additionalBytes): void
    {
        $subscription = SaasSubscription::query()->where('tenant_id', $tenant->id)->first();
        if ($subscription === null || $subscription->status === 'cancelled') {
            return;
        }

        $plan = SaasPlan::query()->where('code', $subscription->plan_code)->first();
        $limit = $plan?->limit('storage_mb');
        if ($plan === null || $limit === null) {
            return;
        }

        if ($this->usage->storageBytes($tenant) + max(0, $additionalBytes) > $limit * 1048576) {
            throw ValidationException::withMessages([
                'storage' => ['saas.limit_storage'],
            ]);
        }
    }

    public function fits(Tenant $tenant, SaasPlan $plan, ?SaasSubscription $subscription = null): bool
    {
        $used = $this->usage->snapshot($tenant, $subscription);

        foreach (['users', 'branches', 'pos', 'products', 'storage_mb', 'transactions'] as $key) {
            $limit = $plan->limit($key);
            if ($limit !== null && ($used[$key] ?? 0) > $limit) {
                return false;
            }
        }

        return true;
    }

    public function assertFits(Tenant $tenant, SaasPlan $plan, ?SaasSubscription $subscription = null): void
    {
        if (! $this->fits($tenant, $plan, $subscription)) {
            throw ValidationException::withMessages([
                'plan' => ['saas.usage_exceeds_plan'],
            ]);
        }
    }

    private function code(string $resource): string
    {
        return match ($resource) {
            'storage_mb' => 'storage',
            default => $resource,
        };
    }
}
