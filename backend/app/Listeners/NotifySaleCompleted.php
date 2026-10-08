<?php

namespace App\Listeners;

use App\Enums\NotificationEvent;
use App\Events\SaleCompleted;
use App\Models\Tenant;
use App\Services\Notifications\NotificationCenter;
use App\Tenancy\TenantContext;
use Illuminate\Contracts\Queue\ShouldQueue;

class NotifySaleCompleted implements ShouldQueue
{
    public function __construct(
        private readonly NotificationCenter $center,
        private readonly TenantContext $tenants,
    ) {}

    public function handle(SaleCompleted $event): void
    {
        $opened = $this->bind($event->tenantId);
        if (! $this->tenants->isBound()) {
            return;
        }

        try {
            $sale = $event->sale;
            $reference = $sale->reference ?: 'Commande';
            $this->center->notify(
                NotificationEvent::NewOrder,
                NotificationEvent::NewOrder->title(),
                $reference,
                ['sale_id' => $sale->id],
                'new_order:'.$sale->id,
            );
        } catch (\Throwable $exception) {
            report($exception);
        } finally {
            if ($opened) {
                $this->tenants->clear();
            }
        }
    }

    private function bind(string $tenantId): bool
    {
        if ($this->tenants->isBound() || $tenantId === '') {
            return false;
        }

        $tenant = Tenant::query()->find($tenantId);
        if ($tenant === null) {
            return false;
        }

        $this->tenants->bind($tenant);

        return true;
    }
}
