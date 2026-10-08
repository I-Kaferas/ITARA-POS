<?php

namespace App\Observers\Realtime;

use App\Enums\CashierShiftStatus;
use App\Models\CashierShift;
use App\Models\CashRegister;
use App\Services\Realtime\RealtimePublisher;

class CashierShiftObserver
{
    public function __construct(private readonly RealtimePublisher $publisher) {}

    public function created(CashierShift $shift): void
    {
        $this->publish($shift, $this->isClosed($shift) ? 'shift.closed' : 'shift.opened');
    }

    public function updated(CashierShift $shift): void
    {
        if ($shift->wasChanged('status')) {
            $this->publish($shift, $this->isClosed($shift) ? 'shift.closed' : 'shift.opened');

            return;
        }

        $this->publish($shift, 'shift.updated');
    }

    private function isClosed(CashierShift $shift): bool
    {
        return $shift->status === CashierShiftStatus::Closed;
    }

    private function publish(CashierShift $shift, string $type): void
    {
        $storeId = $shift->cash_register_id
            ? CashRegister::query()->whereKey($shift->cash_register_id)->value('store_id')
            : null;

        $this->publisher->notify(
            type: $type,
            tenantId: $shift->tenant_id,
            storeId: is_string($storeId) ? $storeId : null,
            entity: 'cashier_shift',
            id: $shift->id,
            status: $shift->status?->value,
            data: [
                'cashier_id' => $shift->cashier_id,
                'branch_id' => $shift->branch_id,
                'cash_register_id' => $shift->cash_register_id,
                'device_id' => $shift->device_id,
                'opened_at' => $shift->opened_at?->toIso8601String(),
                'closed_at' => $shift->closed_at?->toIso8601String(),
                'expected_cash' => $shift->expected_cash,
                'sales_total' => $shift->sales_total,
                'variance' => $shift->variance,
            ],
        );
    }
}
