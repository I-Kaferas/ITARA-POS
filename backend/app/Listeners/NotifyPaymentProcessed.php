<?php

namespace App\Listeners;

use App\Enums\NotificationEvent;
use App\Events\PaymentProcessed;
use App\Services\Notifications\NotificationCenter;
use App\Tenancy\TenantContext;

class NotifyPaymentProcessed
{
    public function __construct(
        private readonly NotificationCenter $center,
        private readonly TenantContext $tenants,
    ) {}

    public function handle(PaymentProcessed $event): void
    {
        $this->tenants->runAs((string) $event->store->tenant_id, function () use ($event): void {
            try {
                $result = $event->result;
                $this->center->notify(
                    NotificationEvent::Payment,
                    NotificationEvent::Payment->title(),
                    trim($result->transactionNumber.' · '.$result->paidTotal.' '.$result->currency),
                    ['store_id' => $event->store->id, 'transaction' => $result->transactionNumber],
                    'payment:'.$result->transactionNumber,
                );
            } catch (\Throwable $exception) {
                report($exception);
            }
        });
    }
}
