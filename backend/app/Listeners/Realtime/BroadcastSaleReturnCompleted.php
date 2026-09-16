<?php

namespace App\Listeners\Realtime;

use App\Events\SaleReturnCompleted;
use App\Services\Realtime\RealtimePublisher;

class BroadcastSaleReturnCompleted
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function handle(SaleReturnCompleted $event): void
    {
        $saleReturn = $event->saleReturn;

        $this->publisher->notify(
            type: 'sale.updated',
            tenantId: $saleReturn->tenant_id,
            storeId: $saleReturn->store_id ?? $saleReturn->sale?->store_id,
            entity: 'sale_return',
            id: $saleReturn->id,
        );
    }
}
