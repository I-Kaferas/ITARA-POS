<?php

namespace App\Services\Services;

use App\Models\ServiceAppointment;
use App\Models\ServiceOffering;
use App\Models\Store;
use App\Models\User;
use App\Services\Sales\SaleEngine;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ServiceDesk
{
    public function __construct(private readonly SaleEngine $sales) {}

    public function ensureDefaults(string $tenantId): void
    {
        if (ServiceOffering::query()->where('tenant_id', $tenantId)->exists()) {
            return;
        }

        $defaults = [
            ['name' => 'Coupe', 'category' => 'salon', 'duration_minutes' => 45, 'price' => 1500000],
            ['name' => 'Vidange', 'category' => 'garage', 'duration_minutes' => 60, 'price' => 3500000],
            ['name' => 'Réparation', 'category' => 'repair', 'duration_minutes' => 90, 'price' => 5000000],
            ['name' => 'Maintenance', 'category' => 'maintenance', 'duration_minutes' => 60, 'price' => 2500000],
        ];

        foreach ($defaults as $row) {
            ServiceOffering::query()->create([...$row, 'tenant_id' => $tenantId, 'is_active' => true]);
        }
    }

    /** @param  array<string, mixed>  $data */
    public function book(string $tenantId, array $data, ?Store $store): ServiceAppointment
    {
        $offering = ServiceOffering::query()->whereKey($data['service_offering_id'])->firstOrFail();

        return ServiceAppointment::query()->create([
            'tenant_id' => $tenantId,
            'store_id' => $store?->id,
            'service_offering_id' => $offering->id,
            'customer_name' => trim((string) $data['customer_name']),
            'scheduled_at' => $data['scheduled_at'],
            'status' => 'booked',
        ]);
    }

    public function assign(ServiceAppointment $appointment, string $employeeId): ServiceAppointment
    {
        $this->assertStatus($appointment, ['booked', 'assigned']);
        User::query()->whereKey($employeeId)->firstOrFail();
        $appointment->forceFill([
            'employee_id' => $employeeId,
            'status' => 'assigned',
        ])->save();

        return $appointment->refresh();
    }

    public function complete(ServiceAppointment $appointment, User $actor, ?string $notes): ServiceAppointment
    {
        $this->assertStatus($appointment, ['assigned']);
        if ($appointment->employee_id === null) {
            throw ValidationException::withMessages([
                'employee_id' => ['Assignez un employé avant de terminer le service.'],
            ]);
        }

        $appointment->forceFill([
            'status' => 'completed',
            'completed_at' => now(),
            'completed_by' => $actor->id,
            'completion_notes' => $notes,
        ])->save();

        return $appointment->refresh();
    }

    public function pay(ServiceAppointment $appointment, Store $store, User $actor, string $method): ServiceAppointment
    {
        $this->assertStatus($appointment, ['completed', 'paid']);
        if ($appointment->status === 'paid') {
            return $appointment;
        }

        $appointment->load('offering');
        $price = (int) $appointment->offering->price;

        return DB::transaction(function () use ($appointment, $store, $actor, $method, $price): ServiceAppointment {
            $saleId = null;
            try {
                $result = $this->sales->create($store, [
                    'idempotency_key' => $appointment->id,
                    'customer_name' => $appointment->customer_name,
                    'notes' => sprintf(
                        'Service %s · %s · %s',
                        $appointment->offering->name,
                        $appointment->offering->category,
                        $appointment->customer_name,
                    ),
                    'items' => [[
                        'name' => $appointment->offering->name,
                        'quantity' => 1,
                        'unit_price' => $price,
                    ]],
                    'payments' => [[
                        'method' => $method,
                        'amount' => $price,
                    ]],
                ], $actor);
                $saleId = $result->sale->id;
            } catch (\Throwable) {
                $saleId = null;
            }

            $appointment->forceFill([
                'status' => 'paid',
                'paid_at' => now(),
                'payment_method' => $method,
                'paid_amount' => $price,
                'sale_id' => $saleId,
            ])->save();

            return $appointment->refresh();
        });
    }

    /** @param  list<string>  $allowed */
    private function assertStatus(ServiceAppointment $appointment, array $allowed): void
    {
        if (! in_array($appointment->status, $allowed, true)) {
            throw ValidationException::withMessages([
                'status' => ['Cette étape n’est pas disponible pour ce rendez-vous.'],
            ]);
        }
    }
}
