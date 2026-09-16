<?php

namespace App\Listeners\Realtime;

use App\Events\PaymentProcessed;
use App\Services\Realtime\RealtimePublisher;

class BroadcastPaymentProcessed
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function handle(PaymentProcessed $event): void
    {
        $this->publisher->notify(
            type: 'payment.completed',
            tenantId: $event->store->tenant_id,
            storeId: $event->store->id,
            entity: 'payment',
            id: $event->result->transactionNumber,
            status: 'processed',
        );
    }
}
