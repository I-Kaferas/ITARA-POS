<?php

namespace App\Observers\Realtime;

use App\Models\SaleItem;
use App\Services\Realtime\RealtimePublisher;

class SaleItemObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(SaleItem $item): void
    {
        $this->publish($item, 'sale.item_added');
    }

    public function updated(SaleItem $item): void
    {
        $this->publish($item, 'sale.updated');
    }

    public function deleted(SaleItem $item): void
    {
        $this->publish($item, 'sale.item_removed');
    }

    private function publish(SaleItem $item, string $type): void
    {
        $sale = $item->relationLoaded('sale') ? $item->sale : $item->sale()->first();

        $this->publisher->notify(
            type: $type,
            tenantId: $item->tenant_id,
            storeId: $sale?->store_id,
            entity: 'sale',
            id: $item->sale_id,
        );
    }
}
