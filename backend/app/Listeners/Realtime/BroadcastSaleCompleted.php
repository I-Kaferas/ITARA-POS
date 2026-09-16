<?php

namespace App\Listeners\Realtime;

use App\Events\SaleCompleted;
use App\Services\Realtime\RealtimePublisher;

class BroadcastSaleCompleted
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function handle(SaleCompleted $event): void
    {
        $sale = $event->sale;

        $this->publisher->notify(
            type: 'sale.completed',
            tenantId: $sale->tenant_id,
            storeId: $sale->store_id,
            entity: 'sale',
            id: $sale->id,
            status: $sale->status?->value,
        );
    }
}
