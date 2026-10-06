<?php

namespace App\Observers\Realtime;

use App\Models\CashMovement;
use App\Models\CashRegister;
use App\Services\Realtime\RealtimePublisher;

class CashMovementObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(CashMovement $movement): void
    {
        $storeId = $movement->cash_register_id
            ? CashRegister::query()->whereKey($movement->cash_register_id)->value('store_id')
            : null;

        $this->publisher->notify(
            type: 'cash.movement.created',
            tenantId: $movement->tenant_id,
            storeId: is_string($storeId) ? $storeId : null,
            entity: 'cash_movement',
            id: $movement->id,
            status: $movement->movement_type?->value,
            data: [
                'amount' => $movement->signedAmount(),
                'cashier_shift_id' => $movement->cashier_shift_id,
            ],
        );
    }
}
