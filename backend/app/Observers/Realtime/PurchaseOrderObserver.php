<?php

namespace App\Observers\Realtime;

use App\Models\PurchaseOrder;
use App\Services\Realtime\RealtimePublisher;

class PurchaseOrderObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(PurchaseOrder $order): void
    {
        $this->publish($order, 'purchase.created');
    }

    public function updated(PurchaseOrder $order): void
    {
        $type = $order->wasChanged('status') ? 'purchase.status.changed' : 'purchase.updated';
        $this->publish($order, $type);
    }

    private function publish(PurchaseOrder $order, string $type): void
    {
        $this->publisher->notify(
            type: $type,
            tenantId: $order->tenant_id,
            entity: 'purchase_order',
            id: $order->id,
            status: $order->status?->value,
            data: [
                'order_number' => $order->order_number,
                'total' => $order->total,
            ],
        );
    }
}
