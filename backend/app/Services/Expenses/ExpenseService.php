<?php

namespace App\Services\Expenses;

use App\Enums\CashMovementType;
use App\Models\Branch;
use App\Models\CashRegisterSession;
use App\Models\Expense;
use App\Models\ExpenseCategory;
use App\Models\User;
use App\Services\Registers\CashRegisterSessionService;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ExpenseService
{
    public function __construct(
        private readonly CashRegisterSessionService $sessions,
    ) {}

    /**
     * @param  array{
     *     branch_id: string,
     *     expense_category_id: string,
     *     description: string,
     *     amount: int,
     *     user_id?: string|null,
     *     cash_register_session_id?: string|null,
     *     store_id?: string|null,
     *     occurred_on?: string|null,
     *     notes?: string|null,
     *     currency_code?: string|null,
     * }  $data
     */
    public function record(array $data, User $actor): Expense
    {
        $branch = Branch::query()->findOrFail($data['branch_id']);
        $category = ExpenseCategory::query()->findOrFail($data['expense_category_id']);

        if ($category->tenant_id !== $branch->tenant_id) {
            throw ValidationException::withMessages([
                'expense_category_id' => ['Catégorie hors de cette entreprise.'],
            ]);
        }

        $session = null;
        if (! empty($data['cash_register_session_id'])) {
            $session = $this->sessionForBranch($branch, $data['cash_register_session_id']);
        }

        if (! empty($data['store_id']) && ! $branch->stores()->whereKey($data['store_id'])->exists()) {
            throw ValidationException::withMessages([
                'store_id' => ['Magasin hors de cette succursale.'],
            ]);
        }

        if (! empty($data['user_id']) && ! User::query()->whereKey($data['user_id'])->exists()) {
            throw ValidationException::withMessages([
                'user_id' => ['Utilisateur introuvable.'],
            ]);
        }

        return DB::transaction(function () use ($data, $actor, $branch, $category, $session): Expense {
            $expense = Expense::query()->create([
                'tenant_id' => $branch->tenant_id,
                'branch_id' => $branch->id,
                'store_id' => $data['store_id'] ?? $session?->register?->store_id,
                'expense_category_id' => $category->id,
                'cash_register_session_id' => $session?->id,
                'user_id' => $data['user_id'] ?? $actor->id,
                'recorded_by' => $actor->id,
                'category' => $category->code,
                'description' => $data['description'],
                'amount' => $data['amount'],
                'currency_code' => strtoupper($data['currency_code'] ?? 'FBU'),
                'occurred_on' => $data['occurred_on'] ?? now()->toDateString(),
                'notes' => $data['notes'] ?? null,
            ]);

            if ($session !== null) {
                $this->sessions->recordMovement(
                    register: $session->register,
                    session: $session,
                    type: CashMovementType::Expense,
                    amount: $expense->amount,
                    user: $actor,
                    description: $category->name.' · '.$expense->description,
                    reference: $expense->id,
                    referenceType: $expense->getMorphClass(),
                    referenceId: $expense->id,
                );
            }

            return $expense->load(['expenseCategory', 'branch', 'user', 'cashRegisterSession.register']);
        });
    }

    private function sessionForBranch(Branch $branch, string $sessionId): CashRegisterSession
    {
        $session = CashRegisterSession::query()
            ->with('register.store')
            ->find($sessionId);

        if ($session === null || $session->register?->store?->branch_id !== $branch->id) {
            throw ValidationException::withMessages([
                'cash_register_session_id' => ['La caisse n’appartient pas à cette succursale.'],
            ]);
        }

        if (! $session->isOpen()) {
            throw ValidationException::withMessages([
                'cash_register_session_id' => ['La session de caisse est fermée.'],
            ]);
        }

        return $session;
    }
}
