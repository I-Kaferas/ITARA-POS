<?php

namespace App\Services\Platform;

use App\Enums\SaleStatus;
use App\Models\Branch;
use App\Models\Device;
use App\Models\GalleryImage;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\SaasSubscription;
use App\Models\Sale;
use App\Models\Tenant;
use App\Models\User;
use App\Tenancy\Scopes\TenantScope;

class SaasUsageMeter
{
    /** @return array{users: int, branches: int, pos: int, products: int, storage_mb: int, transactions: int} */
    public function snapshot(Tenant $tenant, ?SaasSubscription $subscription = null): array
    {
        return [
            'users' => $this->count(User::class, $tenant),
            'branches' => $this->count(Branch::class, $tenant),
            'pos' => Device::query()
                ->withoutGlobalScope(TenantScope::class)
                ->where('tenant_id', $tenant->id)
                ->where('is_active', true)
                ->count(),
            'products' => $this->count(Product::class, $tenant),
            'storage_mb' => (int) ceil($this->storageBytes($tenant) / 1048576),
            'transactions' => $this->transactions($tenant, $subscription),
        ];
    }

    public function storageBytes(Tenant $tenant): int
    {
        $productImages = (int) ProductImage::query()
            ->withoutGlobalScope(TenantScope::class)
            ->where('tenant_id', $tenant->id)
            ->sum('file_size');
        $gallery = (int) GalleryImage::query()
            ->withoutGlobalScope(TenantScope::class)
            ->where('tenant_id', $tenant->id)
            ->sum('file_size');

        return $productImages + $gallery;
    }

    /** @param  class-string  $model */
    private function count(string $model, Tenant $tenant): int
    {
        return $model::query()
            ->withoutGlobalScope(TenantScope::class)
            ->where('tenant_id', $tenant->id)
            ->count();
    }

    private function transactions(Tenant $tenant, ?SaasSubscription $subscription): int
    {
        $from = $subscription?->period_starts_on?->copy()->startOfDay()
            ?? $subscription?->created_at
            ?? now()->startOfMonth();

        return Sale::query()
            ->withoutGlobalScope(TenantScope::class)
            ->where('tenant_id', $tenant->id)
            ->where('status', SaleStatus::Completed->value)
            ->where('created_at', '>=', $from)
            ->count();
    }
}
