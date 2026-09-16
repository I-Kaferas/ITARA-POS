<?php

namespace App\Observers\Realtime;

use App\Models\PosTable;
use App\Services\Realtime\RealtimePublisher;

class PosTableObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(PosTable $table): void
    {
        $this->publish($table, 'table.updated');
    }

    public function updated(PosTable $table): void
    {
        if (! $table->wasChanged(['status', 'current_sale_id', 'is_active'])) {
            return;
        }

        $status = $table->status?->value;
        $type = match ($status) {
            'occupied' => 'table.occupied',
            'available' => 'table.available',
            'reserved' => 'table.reserved',
            default => 'table.updated',
        };

        if ($table->wasChanged('current_sale_id') && $table->getOriginal('current_sale_id') && $table->current_sale_id) {
            $type = 'table.transferred';
        }

        $this->publish($table, $type);
    }

    private function publish(PosTable $table, string $type): void
    {
        $this->publisher->notify(
            type: $type,
            tenantId: $table->tenant_id,
            storeId: $table->store_id,
            entity: 'table',
            id: $table->id,
            status: $table->status?->value,
        );
    }
}
