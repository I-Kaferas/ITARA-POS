<?php

namespace App\Observers\Realtime;

use App\Models\InventoryMovement;
use App\Services\Realtime\RealtimePublisher;

class InventoryMovementObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(InventoryMovement $movement): void
    {
        $this->publisher->notify(
            type: 'stock.updated',
            tenantId: $movement->tenant_id,
            storeId: null,
            entity: 'product',
            id: $movement->product_id,
        );
    }
}
