<?php

namespace App\Observers\Realtime;

use App\Models\PosReservation;
use App\Services\Realtime\RealtimePublisher;

class PosReservationObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(PosReservation $reservation): void
    {
        $this->publish($reservation, 'pos.reservation.created');
    }

    public function updated(PosReservation $reservation): void
    {
        if (! $reservation->wasChanged(['status', 'table_id', 'reserved_at', 'party_size'])) {
            return;
        }

        $this->publish($reservation, 'pos.reservation.updated');
    }

    private function publish(PosReservation $reservation, string $type): void
    {
        $this->publisher->notify(
            type: $type,
            tenantId: $reservation->tenant_id,
            storeId: $reservation->store_id,
            entity: 'pos_reservation',
            id: $reservation->id,
            status: $reservation->status,
        );
    }
}
