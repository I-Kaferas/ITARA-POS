<?php

namespace App\Listeners\Realtime;

use App\Events\PurchaseReceived;
use App\Services\Realtime\RealtimePublisher;

class BroadcastPurchaseReceived
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function handle(PurchaseReceived $event): void
    {
        $order = $event->purchaseOrder;

        $this->publisher->notify(
            type: 'stock.updated',
            tenantId: $order->tenant_id,
            storeId: null,
            entity: 'purchase_order',
            id: $order->id,
            status: 'received',
        );
    }
}
