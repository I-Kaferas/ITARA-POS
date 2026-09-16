<?php

namespace App\Observers\Realtime;

use App\Models\SalePayment;
use App\Services\Realtime\RealtimePublisher;

class SalePaymentObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(SalePayment $payment): void
    {
        $sale = $payment->relationLoaded('sale') ? $payment->sale : $payment->sale()->first();

        $this->publisher->notify(
            type: 'payment.created',
            tenantId: $payment->tenant_id,
            storeId: $sale?->store_id,
            entity: 'payment',
            id: $payment->id,
        );
    }
}
