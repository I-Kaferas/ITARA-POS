<?php

namespace App\Observers\Realtime;

use App\Models\Unit;
use App\Services\Realtime\RealtimePublisher;

class UnitObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(Unit $unit): void
    {
        $this->publish($unit, 'unit.created');
    }

    public function updated(Unit $unit): void
    {
        $this->publish($unit, 'unit.updated');
    }

    private function publish(Unit $unit, string $type): void
    {
        $this->publisher->notify(
            type: $type,
            tenantId: $unit->tenant_id,
            storeId: $unit->store_id,
            entity: 'unit',
            id: $unit->id,
            data: [
                'code' => $unit->code,
                'name' => $unit->name,
                'symbol' => $unit->symbol,
            ],
        );
    }
}
