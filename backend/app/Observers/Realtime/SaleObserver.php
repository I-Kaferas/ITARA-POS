<?php

namespace App\Observers\Realtime;

use App\Enums\SaleStatus;
use App\Models\Sale;
use App\Services\Realtime\RealtimePublisher;

class SaleObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(Sale $sale): void
    {
        $this->publish($sale, 'sale.created');
    }

    public function updated(Sale $sale): void
    {
        $type = 'sale.updated';
        if ($sale->wasChanged('status')) {
            $type = match ($sale->status) {
                SaleStatus::Completed => 'sale.completed',
                SaleStatus::Voided => 'sale.cancelled',
                SaleStatus::Merged => 'sale.merged',
                default => 'sale.updated',
            };
        }

        $this->publish($sale, $type);

        if ($sale->wasChanged('payment_status') && $sale->payment_status?->value === 'paid') {
            $this->publisher->notify(
                type: 'payment.completed',
                tenantId: $sale->tenant_id,
                storeId: $sale->store_id,
                entity: 'sale',
                id: $sale->id,
                status: $sale->payment_status?->value,
            );
        }
    }

    private function publish(Sale $sale, string $type): void
    {
        $this->publisher->notify(
            type: $type,
            tenantId: $sale->tenant_id,
            storeId: $sale->store_id,
            entity: 'sale',
            id: $sale->id,
            status: $sale->status?->value,
        );
    }
}
