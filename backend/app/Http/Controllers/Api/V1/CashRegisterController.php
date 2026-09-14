<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\CashMovementType;
use App\Http\Controllers\Controller;
use App\Models\CashRegister;
use App\Models\CashRegisterSession;
use App\Models\Store;
use App\Services\Registers\CashRegisterSessionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CashRegisterController extends Controller
{
    public function __construct(
        private readonly CashRegisterSessionService $sessionService,
    ) {}

    public function movementTypes(): JsonResponse
    {
        $types = collect(config('registers.movement_types'))
            ->map(fn (array $meta, string $value) => [
                'value' => $value,
                'label' => $meta['label'],
                'label_fr' => $meta['label_fr'],
                'direction' => $meta['direction'],
            ])
            ->values();

        return response()->json(['data' => $types]);
    }

    public function index(Store $store): JsonResponse
    {
        $registers = $store->cashRegisters()
            ->with(['device', 'openSession.openedByUser'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json(['data' => $registers]);
    }

    public function store(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:50'],
            'device_id' => ['nullable', 'uuid', 'exists:devices,id'],
            'is_active' => ['boolean'],
        ]);

        $register = $store->cashRegisters()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $register], 201);
    }

    public function show(CashRegister $cashRegister): JsonResponse
    {
        $cashRegister->load(['store', 'device', 'openSession.openedByUser']);

        return response()->json(['data' => $cashRegister]);
    }

    public function update(Request $request, CashRegister $cashRegister): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:50'],
            'device_id' => ['nullable', 'uuid', 'exists:devices,id'],
            'is_active' => ['boolean'],
        ]);

        $cashRegister->update($data);

        return response()->json(['data' => $cashRegister->fresh(['store', 'device', 'openSession'])]);
    }

    public function destroy(CashRegister $cashRegister): JsonResponse
    {
        if ($cashRegister->openSession()->exists()) {
            return response()->json([
                'message' => 'Cannot delete a register with an open session.',
            ], 422);
        }

        $cashRegister->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    public function currentSession(CashRegister $cashRegister): JsonResponse
    {
        $session = $this->sessionService->currentSession($cashRegister);

        if ($session === null) {
            return response()->json(['data' => null]);
        }

        return response()->json([
            'data' => $session,
            'summary' => $this->sessionService->summary($session),
        ]);
    }

    public function openSession(Request $request, CashRegister $cashRegister): JsonResponse
    {
        $data = $request->validate([
            'opening_balance' => ['nullable', 'integer', 'min:0'],
            'opening_notes' => ['nullable', 'string'],
        ]);

        $session = $this->sessionService->open(
            $cashRegister,
            $request->user(),
            (int) ($data['opening_balance'] ?? 0),
            $data['opening_notes'] ?? null,
        );

        return response()->json([
            'data' => $session,
            'summary' => $this->sessionService->summary($session),
        ], 201);
    }

    public function closeSession(Request $request, CashRegister $cashRegister): JsonResponse
    {
        $data = $request->validate([
            'actual_cash' => ['required', 'integer', 'min:0'],
            'closing_notes' => ['nullable', 'string'],
            'variance_reason' => ['nullable', 'string', 'max:500'],
        ]);

        $session = $this->sessionService->close(
            $cashRegister,
            $request->user(),
            (int) $data['actual_cash'],
            $data['closing_notes'] ?? null,
            $data['variance_reason'] ?? null,
        );

        $summary = $this->sessionService->summary($session);

        return response()->json([
            'data' => $session,
            'summary' => $summary,
            'z_report' => $summary,
        ]);
    }

    public function sessions(CashRegister $cashRegister): JsonResponse
    {
        $sessions = $cashRegister->sessions()
            ->with(['openedByUser', 'closedByUser'])
            ->orderByDesc('opened_at')
            ->limit(50)
            ->get();

        return response()->json(['data' => $sessions]);
    }

    public function showSession(CashRegister $cashRegister, CashRegisterSession $session): JsonResponse
    {
        if ($session->cash_register_id !== $cashRegister->id) {
            abort(404);
        }

        $session->load(['openedByUser', 'closedByUser', 'movements.performedBy']);

        return response()->json([
            'data' => $session,
            'summary' => $this->sessionService->summary($session),
        ]);
    }

    public function movements(Request $request, CashRegister $cashRegister): JsonResponse
    {
        $query = $cashRegister->movements()
            ->with(['performedBy', 'session'])
            ->orderByDesc('occurred_at');

        if ($request->filled('session_id')) {
            $query->where('cash_register_session_id', $request->string('session_id'));
        }

        return response()->json(['data' => $query->limit(100)->get()]);
    }

    public function recordMovement(Request $request, CashRegister $cashRegister): JsonResponse
    {
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

        $session = $this->sessionService->currentSession($cashRegister);

        if ($session === null) {
            throw ValidationException::withMessages([
                'cash_register' => ['Aucune session ouverte sur cette caisse.'],
            ]);
        }

        $openShift = $cashRegister->openCashierShift()->first();

        $movement = $this->sessionService->recordMovement(
            $cashRegister,
            $session,
            CashMovementType::from($data['movement_type']),
            (int) $data['amount'],
            $request->user(),
            $data['description'] ?? null,
            $data['reference'] ?? null,
            $data['reference_type'] ?? null,
            $data['reference_id'] ?? null,
            $openShift?->id,
        );

        $session->refresh();

        return response()->json([
            'data' => $movement,
            'summary' => $this->sessionService->summary($session),
        ], 201);
    }
}
