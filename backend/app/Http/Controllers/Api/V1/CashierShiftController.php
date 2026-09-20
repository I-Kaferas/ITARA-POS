<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\CashMovementType;
use App\Http\Controllers\Controller;
use App\Models\CashierShift;
use App\Models\CashRegister;
use App\Models\Store;
use App\Models\User;
use App\Services\Shifts\CashierShiftService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CashierShiftController extends Controller
{
    public function __construct(
        private readonly CashierShiftService $shiftService,
    ) {}

    public function currentForUser(Request $request): JsonResponse
    {
        $shift = $this->shiftService->currentShiftForCashier($request->user());

        if ($shift === null) {
            return response()->json(['data' => null]);
        }

        return response()->json([
            'data' => $shift,
            'summary' => $this->shiftService->summary($shift),
        ]);
    }

    public function indexForStore(Store $store): JsonResponse
    {
        $shifts = CashierShift::query()
            ->whereHas('cashRegister', fn ($q) => $q->where('store_id', $store->id))
            ->with(['cashier', 'cashRegister'])
            ->orderByDesc('opened_at')
            ->limit(50)
            ->get();

        return response()->json(['data' => $shifts]);
    }

    public function showForStore(Store $store, CashierShift $cashierShift): JsonResponse
    {
        $cashierShift->load(['cashier', 'cashRegister', 'registerSession', 'movements.performedBy']);

        if ($cashierShift->cashRegister?->store_id !== $store->id) {
            abort(404);
        }

        return response()->json([
            'data' => $cashierShift,
            'summary' => $this->shiftService->summary($cashierShift),
        ]);
    }

    public function showShift(CashierShift $cashierShift): JsonResponse
    {
        $cashierShift->load(['cashier', 'cashRegister.store', 'registerSession', 'movements.performedBy']);

        return response()->json([
            'data' => $cashierShift,
            'summary' => $this->shiftService->summary($cashierShift),
        ]);
    }

    public function currentOnRegister(CashRegister $cashRegister): JsonResponse
    {
        $shift = $this->shiftService->currentShiftOnRegister($cashRegister);

        if ($shift === null) {
            return response()->json(['data' => null]);
        }

        return response()->json([
            'data' => $shift,
            'summary' => $this->shiftService->summary($shift),
        ]);
    }

    public function open(Request $request, CashRegister $cashRegister): JsonResponse
    {
        $data = $request->validate([
            'opening_balance' => ['nullable', 'integer', 'min:0'],
            'opening_notes' => ['nullable', 'string'],
            'opened_at' => ['nullable', 'date'],
        ]);

        $shift = $this->shiftService->open(
            $cashRegister,
            $request->user(),
            (int) ($data['opening_balance'] ?? 0),
            $data['opening_notes'] ?? null,
            isset($data['opened_at']) ? \Carbon\Carbon::parse($data['opened_at']) : null,
        );

        return response()->json([
            'data' => $shift,
            'summary' => $this->shiftService->summary($shift),
        ], 201);
    }

    public function close(Request $request, CashRegister $cashRegister): JsonResponse
    {
        $data = $request->validate([
            'actual_cash' => ['required', 'integer', 'min:0'],
            'closing_notes' => ['nullable', 'string'],
            'variance_reason' => ['nullable', 'string', 'max:500'],
            'closed_at' => ['nullable', 'date'],
        ]);

        $shift = $this->shiftService->close(
            $cashRegister,
            $request->user(),
            (int) $data['actual_cash'],
            $data['closing_notes'] ?? null,
            isset($data['closed_at']) ? \Carbon\Carbon::parse($data['closed_at']) : null,
            $data['variance_reason'] ?? null,
        );

        return response()->json([
            'data' => $shift,
            'summary' => $this->shiftService->summary($shift),
        ]);
    }

    public function openWithPin(Request $request, CashRegister $cashRegister): JsonResponse
    {
        $data = $request->validate([
            'pin' => ['required', 'regex:/^\d{4,6}$/'],
            'opening_balance' => ['nullable', 'integer', 'min:0'],
            'opening_notes' => ['nullable', 'string'],
        ]);

        $cashier = $this->userByPin($request, $data['pin']);
        $shift = $this->shiftService->open(
            $cashRegister,
            $cashier,
            (int) ($data['opening_balance'] ?? 0),
            $data['opening_notes'] ?? null,
        );

        return response()->json([
            'data' => $shift,
            'summary' => $this->shiftService->summary($shift),
        ], 201);
    }

    public function closeWithPin(Request $request, CashRegister $cashRegister): JsonResponse
    {
        $data = $request->validate([
            'pin' => ['required', 'regex:/^\d{4,6}$/'],
            'actual_cash' => ['required', 'integer', 'min:0'],
            'closing_notes' => ['nullable', 'string'],
            'variance_reason' => ['nullable', 'string', 'max:500'],
        ]);

        $this->userByPin($request, $data['pin']);
        $open = $this->shiftService->currentShiftOnRegister($cashRegister)?->loadMissing('cashier');
        if ($open?->cashier === null) {
            throw \Illuminate\Validation\ValidationException::withMessages([
                'cash_register' => ['No open cashier shift on this terminal.'],
            ]);
        }

        $shift = $this->shiftService->close(
            $cashRegister,
            $open->cashier,
            (int) $data['actual_cash'],
            $data['closing_notes'] ?? null,
            null,
            $data['variance_reason'] ?? null,
        );

        return response()->json([
            'data' => $shift,
            'summary' => $this->shiftService->summary($shift),
        ]);
    }

    public function index(CashRegister $cashRegister): JsonResponse
    {
        $shifts = $cashRegister->cashierShifts()
            ->with(['cashier'])
            ->orderByDesc('opened_at')
            ->limit(50)
            ->get();

        return response()->json(['data' => $shifts]);
    }

    public function show(CashRegister $cashRegister, CashierShift $cashierShift): JsonResponse
    {
        if ($cashierShift->cash_register_id !== $cashRegister->id) {
            abort(404);
        }

        $cashierShift->load(['cashier', 'registerSession', 'movements.performedBy']);

        return response()->json([
            'data' => $cashierShift,
            'summary' => $this->shiftService->summary($cashierShift),
        ]);
    }

    public function recordMovement(Request $request, CashRegister $cashRegister, CashierShift $cashierShift): JsonResponse
    {
        if ($cashierShift->cash_register_id !== $cashRegister->id) {
            abort(404);
        }

        $data = $request->validate([
            'movement_type' => ['required', 'string', Rule::in([
                CashMovementType::CashIn->value,
                CashMovementType::CashOut->value,
                CashMovementType::Expense->value,
            ])],
            'amount' => ['required', 'integer', 'min:1'],
            'description' => ['nullable', 'string', 'max:500'],
            'reference' => ['nullable', 'string', 'max:100'],
            'reference_type' => ['nullable', 'string', 'max:100'],
            'reference_id' => ['nullable', 'uuid'],
        ]);

        $movement = $this->shiftService->recordMovement(
            $cashRegister,
            $cashierShift,
            CashMovementType::from($data['movement_type']),
            (int) $data['amount'],
            $request->user(),
            $data['description'] ?? null,
            $data['reference'] ?? null,
            $data['reference_type'] ?? null,
            $data['reference_id'] ?? null,
        );

        $cashierShift->refresh();

        return response()->json([
            'data' => $movement,
            'summary' => $this->shiftService->summary($cashierShift),
        ], 201);
    }

    private function userByPin(Request $request, string $pin): User
    {
        $user = User::query()->where('pin', $pin)->where('is_active', true)->first();

        if ($user === null) {
            throw \Illuminate\Validation\ValidationException::withMessages([
                'pin' => ['PIN invalide.'],
            ]);
        }

        return $user;
    }
}
