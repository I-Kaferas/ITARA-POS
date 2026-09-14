<?php

namespace App\Services\Registers;

use App\Enums\CashMovementType;
use App\Enums\CashRegisterSessionStatus;
use App\Models\CashierShift;
use App\Models\CashMovement;
use App\Models\CashRegister;
use App\Models\CashRegisterSession;
use App\Models\User;
use App\Services\Shifts\CashierShiftService;
use App\Services\Shifts\ShiftReportBuilder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CashRegisterSessionService
{
    public function open(
        CashRegister $register,
        User $user,
        int $openingBalance = 0,
        ?string $notes = null,
    ): CashRegisterSession {
        if ($register->openSession()->exists()) {
            throw ValidationException::withMessages([
                'cash_register' => ['A session is already open on this register.'],
            ]);
        }

        return DB::transaction(function () use ($register, $user, $openingBalance, $notes) {
            $session = CashRegisterSession::query()->create([
                'tenant_id' => $register->tenant_id,
                'cash_register_id' => $register->id,
                'opened_by' => $user->id,
                'status' => CashRegisterSessionStatus::Open,
                'opening_balance' => max(0, $openingBalance),
                'expected_cash' => max(0, $openingBalance),
                'opening_notes' => $notes,
                'opened_at' => now(),
            ]);

            if ($openingBalance > 0) {
                CashMovement::query()->create([
                    'tenant_id' => $register->tenant_id,
                    'cash_register_id' => $register->id,
                    'cash_register_session_id' => $session->id,
                    'movement_type' => CashMovementType::OpeningBalance,
                    'amount' => $openingBalance,
                    'description' => 'Opening balance',
                    'performed_by' => $user->id,
                    'occurred_at' => now(),
                ]);
                $this->refreshTotals($session);
            }

            return $session->fresh(['openedByUser', 'movements']);
        });
    }

    public function close(
        CashRegister $register,
        User $user,
        int $actualCash,
        ?string $notes = null,
        ?string $varianceReason = null,
    ): CashRegisterSession {
        $session = $this->requireOpenSession($register);

        return DB::transaction(function () use ($session, $user, $actualCash, $notes, $varianceReason) {
            $this->refreshTotals($session);

            $expected = $session->expected_cash;
            $variance = $actualCash - $expected;
            $this->assertVarianceJustified($variance, $varianceReason);

            $session->update([
                'status' => CashRegisterSessionStatus::Closed,
                'closed_by' => $user->id,
                'actual_cash' => $actualCash,
                'variance' => $variance,
                'variance_reason' => $variance !== 0 ? trim((string) $varianceReason) : null,
                'closing_notes' => $notes,
                'closed_at' => now(),
            ]);

            return $session->fresh(['openedByUser', 'closedByUser', 'movements']);
        });
    }

    public function recordMovement(
        CashRegister $register,
        CashRegisterSession $session,
        CashMovementType $type,
        int $amount,
        User $user,
        ?string $description = null,
        ?string $reference = null,
        ?string $referenceType = null,
        ?string $referenceId = null,
        ?string $cashierShiftId = null,
    ): CashMovement {
        if (! $session->isOpen()) {
            throw ValidationException::withMessages([
                'cash_register_session' => ['Session is closed.'],
            ]);
        }

        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['Amount must be greater than zero.'],
            ]);
        }

        if ($type === CashMovementType::OpeningBalance) {
            throw ValidationException::withMessages([
                'movement_type' => ['Opening balance is recorded when opening the session.'],
            ]);
        }

        return DB::transaction(function () use (
            $register,
            $session,
            $type,
            $amount,
            $user,
            $description,
            $reference,
            $referenceType,
            $referenceId,
            $cashierShiftId,
        ) {
            $movement = CashMovement::query()->create([
                'tenant_id' => $register->tenant_id,
                'cash_register_id' => $register->id,
                'cash_register_session_id' => $session->id,
                'cashier_shift_id' => $cashierShiftId,
                'movement_type' => $type,
                'amount' => $amount,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'reference' => $reference,
                'description' => $description,
                'performed_by' => $user->id,
                'occurred_at' => now(),
            ]);

            $this->refreshTotals($session);

            if ($cashierShiftId !== null) {
                $shift = CashierShift::query()->find($cashierShiftId);
                if ($shift !== null) {
                    app(CashierShiftService::class)->refreshTotals($shift);
                }
            }

            return $movement;
        });
    }

    public function currentSession(CashRegister $register): ?CashRegisterSession
    {
        return $register->sessions()
            ->where('status', CashRegisterSessionStatus::Open)
            ->with(['openedByUser', 'movements' => fn ($q) => $q->orderByDesc('occurred_at')])
            ->latest('opened_at')
            ->first();
    }

    public function summary(CashRegisterSession $session): array
    {
        $this->refreshTotals($session);
        $session->refresh();

        $report = ShiftReportBuilder::forRegisterSession($session);

        return [
            'session_id' => $session->id,
            'status' => $session->status->value,
            'opening_balance' => $session->opening_balance,
            'sales_total' => $session->sales_total,
            'cash_in_total' => $session->cash_in_total,
            'cash_out_total' => $session->cash_out_total,
            'expenses_total' => $session->expenses_total,
            'expected_cash' => $session->expected_cash,
            'actual_cash' => $session->actual_cash,
            'variance' => $session->variance,
            'variance_reason' => $session->variance_reason,
            'opened_at' => $session->opened_at,
            'closed_at' => $session->closed_at,
            'invoices_count' => $report['invoices_count'],
            'invoices_total' => $report['invoices_total'],
            'invoices' => $report['invoices'],
            'payment_methods' => $report['payment_methods'],
        ];
    }

    public function refreshTotals(CashRegisterSession $session): void
    {
        $movements = $session->movements()->get();

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

        $session->update([
            'sales_total' => $sales,
            'cash_in_total' => $cashIn,
            'cash_out_total' => $cashOut,
            'expenses_total' => $expenses,
            'expected_cash' => max(0, $expected),
        ]);
    }

    private function assertVarianceJustified(int $variance, ?string $reason): void
    {
        if ($variance !== 0 && trim((string) $reason) === '') {
            throw ValidationException::withMessages([
                'variance_reason' => ['Une différence de caisse doit être justifiée.'],
            ]);
        }
    }

    private function requireOpenSession(CashRegister $register): CashRegisterSession
    {
        $session = $this->currentSession($register);

        if ($session === null) {
            throw ValidationException::withMessages([
                'cash_register' => ['No open session on this register.'],
            ]);
        }

        return $session;
    }
}
