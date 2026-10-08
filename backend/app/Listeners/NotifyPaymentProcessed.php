<?php

namespace App\Listeners;

use App\Enums\NotificationEvent;
use App\Events\PaymentProcessed;
use App\Models\Tenant;
use App\Services\Notifications\NotificationCenter;
use App\Tenancy\TenantContext;
use Illuminate\Contracts\Queue\ShouldQueue;

class NotifyPaymentProcessed implements ShouldQueue
{
    public function __construct(
        private readonly NotificationCenter $center,
        private readonly TenantContext $tenants,
    ) {}

    public function handle(PaymentProcessed $event): void
    {
        $tenantId = (string) $event->store->tenant_id;
        $opened = $this->bind($tenantId);
        if (! $this->tenants->isBound()) {
            return;
        }

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
