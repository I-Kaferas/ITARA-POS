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
            type: 'purchase.received',
            tenantId: $order->tenant_id,
            entity: 'purchase_order',
            id: $order->id,
            status: 'received',
            data: ['total' => $order->total],
        );
    }
}
