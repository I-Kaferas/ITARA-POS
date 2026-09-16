<?php

namespace App\Listeners\Realtime;

use App\Events\StockLow;
use App\Services\Realtime\RealtimePublisher;

class BroadcastStockLow
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function handle(StockLow $event): void
    {
        $alert = $event->alert;

        $this->publisher->notify(
            type: 'stock.updated',
            tenantId: $alert->tenant_id,
            storeId: null,
            entity: 'alert',
            id: $alert->id,
            status: $alert->alert_type?->value,
        );
    }
}
