<?php

namespace App\Services\Shifts;

use App\Enums\CashMovementType;
use App\Enums\CashierShiftStatus;
use App\Enums\SalePaymentMethod;
use App\Models\CashierShift;
use App\Models\CashMovement;
use App\Models\CashRegister;
use App\Models\CashRegisterSession;
use App\Models\Sale;
use App\Models\SalePayment;
use App\Models\User;
use App\Services\Registers\CashRegisterSessionService;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CashierShiftService
{
    public function __construct(
        private readonly CashRegisterSessionService $registerSessionService,
    ) {}

    public function open(
        CashRegister $register,
        User $cashier,
        int $openingBalance = 0,
        ?string $notes = null,
        ?Carbon $openedAt = null,
    ): CashierShift {
        $session = $this->registerSessionService->currentSession($register);

        if ($session === null) {
            $session = $this->registerSessionService->open($register, $cashier, 0, $notes);
        }

        if ($register->openCashierShift()->exists()) {
            throw ValidationException::withMessages([
                'cash_register' => ['A cashier shift is already open on this terminal.'],
            ]);
        }

        if (CashierShift::query()
            ->where('cashier_id', $cashier->id)
            ->where('status', CashierShiftStatus::Open)
            ->exists()) {
            throw ValidationException::withMessages([
                'cashier' => ['You already have an open shift. Close it before opening another.'],
            ]);
        }

        $openedAt = $this->exactMoment($openedAt, 'opened_at');

        return DB::transaction(function () use ($register, $cashier, $session, $openingBalance, $notes, $openedAt) {
            $shift = CashierShift::query()->create([
                'tenant_id' => $register->tenant_id,
                'cashier_id' => $cashier->id,
                'cash_register_id' => $register->id,
                'cash_register_session_id' => $session->id,
                'status' => CashierShiftStatus::Open,
                'opening_balance' => max(0, $openingBalance),
                'expected_cash' => max(0, $openingBalance),
                'opening_notes' => $notes,
                'opened_at' => $openedAt,
            ]);

            if ($openingBalance > 0) {
                CashMovement::query()->create([
                    'tenant_id' => $register->tenant_id,
                    'cash_register_id' => $register->id,
                    'cash_register_session_id' => $session->id,
                    'cashier_shift_id' => $shift->id,
                    'movement_type' => CashMovementType::OpeningBalance,
                    'amount' => $openingBalance,
                    'description' => 'Shift opening balance',
                    'performed_by' => $cashier->id,
                    'occurred_at' => $openedAt,
                ]);
                $this->refreshTotals($shift);
                $this->registerSessionService->refreshTotals($session);
            }

            return $shift->fresh(['cashier', 'cashRegister', 'registerSession']);
        });
    }

    public function close(
        CashRegister $register,
        User $cashier,
        int $actualCash,
        ?string $notes = null,
        ?Carbon $closedAt = null,
    ): CashierShift {
        $shift = $this->requireOpenShiftForCashier($register, $cashier);
        $closedAt = $this->exactMoment($closedAt, 'closed_at');

        if ($closedAt->lt($shift->opened_at)) {
            throw ValidationException::withMessages([
                'closed_at' => ['Closing time must be on or after the exact opening time.'],
            ]);
        }

        return DB::transaction(function () use ($shift, $register, $cashier, $actualCash, $notes, $closedAt) {
            $this->refreshTotals($shift);
            $shift->refresh();

            $expected = $shift->expected_cash;
            $variance = $actualCash - $expected;

            $shift->update([
                'status' => CashierShiftStatus::Closed,
                'actual_cash' => $actualCash,
                'variance' => $variance,
                'closing_notes' => $notes,
                'closed_at' => $closedAt,
            ]);

            return $shift->fresh(['cashier', 'cashRegister', 'registerSession']);
        });
    }

    public function recordMovement(
        CashRegister $register,
        CashierShift $shift,
        CashMovementType $type,
        int $amount,
        User $user,
        ?string $description = null,
        ?string $reference = null,
        ?string $referenceType = null,
        ?string $referenceId = null,
    ): CashMovement {
        if (! $shift->isOpen()) {
            throw ValidationException::withMessages([
                'cashier_shift' => ['Shift is closed.'],
            ]);
        }

        if ($shift->cash_register_id !== $register->id) {
            throw ValidationException::withMessages([
                'cash_register' => ['Shift does not belong to this terminal.'],
            ]);
        }

        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['Amount must be greater than zero.'],
            ]);
        }

        if ($type === CashMovementType::OpeningBalance) {
            throw ValidationException::withMessages([
                'movement_type' => ['Opening balance is recorded when opening the shift.'],
            ]);
        }

        $session = $this->registerSessionService->currentSession($register);

        if ($session === null) {
            throw ValidationException::withMessages([
                'cash_register' => ['No open register session on this terminal.'],
            ]);
        }

        return DB::transaction(function () use (
            $register,
            $shift,
            $session,
            $type,
            $amount,
            $user,
            $description,
            $reference,
            $referenceType,
            $referenceId,
        ) {
            $movement = CashMovement::query()->create([
                'tenant_id' => $register->tenant_id,
                'cash_register_id' => $register->id,
                'cash_register_session_id' => $session->id,
                'cashier_shift_id' => $shift->id,
                'movement_type' => $type,
                'amount' => $amount,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'reference' => $reference,
                'description' => $description,
                'performed_by' => $user->id,
                'occurred_at' => now(),
            ]);

            $this->refreshTotals($shift);
            $this->registerSessionService->refreshTotals($session);

            return $movement;
        });
    }

    public function currentShiftOnRegister(CashRegister $register): ?CashierShift
    {
        return $register->cashierShifts()
            ->where('status', CashierShiftStatus::Open)
            ->with(['cashier', 'registerSession'])
            ->latest('opened_at')
            ->first();
    }

    public function currentShiftForCashier(User $cashier): ?CashierShift
    {
        return CashierShift::query()
            ->where('cashier_id', $cashier->id)
            ->where('status', CashierShiftStatus::Open)
            ->with(['cashier', 'cashRegister', 'registerSession'])
            ->latest('opened_at')
            ->first();
    }

    public function recordCompletedSale(Sale $sale, User $user): void
    {
        if ($sale->cashier_shift_id === null) {
            return;
        }

        $shift = CashierShift::query()->find($sale->cashier_shift_id);
        if ($shift === null || ! $shift->isOpen()) {
            return;
        }

        $this->refreshTotals($shift);
    }

    public function summary(CashierShift $shift): array
    {
        $this->refreshTotals($shift);
        $shift->refresh();

        $completedSales = Sale::query()
            ->where('cashier_shift_id', $shift->id)
            ->where('status', 'completed');

        $report = ShiftReportBuilder::forCashierShift($shift);

        return [
            'shift_id' => $shift->id,
            'cashier_id' => $shift->cashier_id,
            'cash_register_id' => $shift->cash_register_id,
            'status' => $shift->status->value,
            'opening_balance' => $shift->opening_balance,
            'sales_count' => (int) (clone $completedSales)->count(),
            'sales_total' => (int) (clone $completedSales)->sum('total'),
            'refunds_total' => $shift->refunds_total,
            'discounts_total' => $shift->discounts_total,
            'cash_in_total' => $shift->cash_in_total,
            'cash_out_total' => $shift->cash_out_total,
            'expenses_total' => $shift->expenses_total,
            'expected_cash' => $shift->expected_cash,
            'actual_cash' => $shift->actual_cash,
            'variance' => $shift->variance,
            'opened_at' => $shift->opened_at,
            'closed_at' => $shift->closed_at,
            'invoices_count' => $report['invoices_count'],
            'invoices_total' => $report['invoices_total'],
            'invoices' => $report['invoices'],
            'payment_methods' => $report['payment_methods'],
        ];
    }

    public function refreshTotals(CashierShift $shift): void
    {
        $movements = $shift->movements()->get();

        $sales = 0;
        $refunds = 0;
        $discounts = 0;
        $cashIn = 0;
        $cashOut = 0;
        $expenses = 0;
        $expected = 0;

        foreach ($movements as $movement) {
            $expected += $movement->signedAmount();

            match ($movement->movement_type) {
                CashMovementType::Sale => $sales += $movement->amount,
                CashMovementType::Refund => $refunds += $movement->amount,
                CashMovementType::Discount => $discounts += $movement->amount,
                CashMovementType::CashIn => $cashIn += $movement->amount,
                CashMovementType::CashOut => $cashOut += $movement->amount,
                CashMovementType::Expense => $expenses += $movement->amount,
                default => null,
            };
        }

        $linkedSaleCash = (int) $movements
            ->where('movement_type', CashMovementType::Sale)
            ->sum('amount');

        $cashSales = (int) SalePayment::query()
            ->whereHas('sale', function ($query) use ($shift) {
                $query->where('cashier_shift_id', $shift->id)->where('status', 'completed');
            })
            ->where(function ($query) {
                $query->where('payment_method', SalePaymentMethod::Cash->value)
                    ->orWhereHas('paymentTransaction', function ($tx) {
                        $tx->where('payment_method', SalePaymentMethod::Cash->value);
                    });
            })
            ->sum('amount');

        $expected += max(0, $cashSales - $linkedSaleCash);

        $shift->update([
            'sales_total' => $sales,
            'refunds_total' => $refunds,
            'discounts_total' => $discounts,
            'cash_in_total' => $cashIn,
            'cash_out_total' => $cashOut,
            'expenses_total' => $expenses,
            'expected_cash' => max(0, $expected),
        ]);
    }

    private function exactMoment(?Carbon $moment, string $field): Carbon
    {
        $exact = ($moment ?? now())->microseconds(0);

        if ($exact->gt(now()->addMinute())) {
            throw ValidationException::withMessages([
                $field => ['The exact time cannot be in the future.'],
            ]);
        }

        return $exact;
    }

    private function requireOpenShiftForCashier(CashRegister $register, User $cashier): CashierShift
    {
        $shift = $this->currentShiftOnRegister($register);

        if ($shift === null) {
            throw ValidationException::withMessages([
                'cash_register' => ['No open cashier shift on this terminal.'],
            ]);
        }

        if ($shift->cashier_id !== $cashier->id) {
            throw ValidationException::withMessages([
                'cashier' => ['Only the active cashier can close this shift.'],
            ]);
        }

        return $shift;
    }
}
