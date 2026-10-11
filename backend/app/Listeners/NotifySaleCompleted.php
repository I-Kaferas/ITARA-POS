<?php

namespace App\Listeners;

use App\Enums\NotificationEvent;
use App\Events\SaleCompleted;
use App\Services\Notifications\NotificationCenter;
use App\Tenancy\TenantContext;

class NotifySaleCompleted
{
    public function __construct(
        private readonly NotificationCenter $center,
        private readonly TenantContext $tenants,
    ) {}

    public function handle(SaleCompleted $event): void
    {
        $this->tenants->runAs($event->tenantId, function () use ($event): void {
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
            }
        });
    }
}
