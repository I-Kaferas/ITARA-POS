<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use App\Models\ExpenseCategory;
use App\Services\Expenses\ExpenseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ExpenseController extends Controller
{
    public function __construct(
        private readonly ExpenseService $expenses,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $this->ensureCategories();

        $query = Expense::query()
            ->with(['expenseCategory', 'branch:id,name', 'user:id,name', 'cashRegisterSession.register:id,name'])
            ->orderByDesc('occurred_on')
            ->orderByDesc('created_at');

        if ($request->filled('branch_id')) {
            $query->where('branch_id', $request->string('branch_id'));
        }

        if ($request->filled('expense_category_id')) {
            $query->where('expense_category_id', $request->string('expense_category_id'));
        }

        return response()->json(['data' => $query->limit(200)->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'branch_id' => ['required', 'uuid', 'exists:branches,id'],
            'expense_category_id' => ['required', 'uuid', 'exists:expense_categories,id'],
            'description' => ['required', 'string', 'max:255'],
            'amount' => ['required', 'integer', 'min:1'],
            'user_id' => ['nullable', 'uuid', 'exists:users,id'],
            'cash_register_session_id' => ['nullable', 'uuid', 'exists:cash_register_sessions,id'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
            'occurred_on' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'currency_code' => ['nullable', 'string', 'size:3'],
        ]);

        $expense = $this->expenses->record($data, $request->user());

        return response()->json(['data' => $expense], 201);
    }

    public function show(Expense $expense): JsonResponse
    {
        return response()->json([
            'data' => $expense->load(['expenseCategory', 'branch', 'user', 'recordedBy', 'cashRegisterSession.register']),
        ]);
    }

    public function update(Request $request, Expense $expense): JsonResponse
    {
        $data = $request->validate([
            'description' => ['sometimes', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'user_id' => ['nullable', 'uuid', 'exists:users,id'],
            'occurred_on' => ['sometimes', 'date'],
        ]);

        $expense->update($data);

        return response()->json(['data' => $expense->fresh(['expenseCategory', 'branch', 'user'])]);
    }

    public function categories(): JsonResponse
    {
        $this->ensureCategories();

        return response()->json([
            'data' => ExpenseCategory::query()->orderBy('sort_order')->orderBy('name')->get(),
        ]);
    }

    public function storeCategory(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'code' => ['nullable', 'string', 'max:40'],
        ]);

        $category = ExpenseCategory::query()->create([
            'tenant_id' => app('tenant.id'),
            'name' => $data['name'],
            'code' => $data['code'] ?? str($data['name'])->slug('_')->limit(40, '')->toString(),
            'is_active' => true,
            'sort_order' => 100,
        ]);

        return response()->json(['data' => $category], 201);
    }

    public function updateCategory(Request $request, ExpenseCategory $expenseCategory): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $expenseCategory->update($data);

        return response()->json(['data' => $expenseCategory]);
    }

    public function dashboard(): JsonResponse
    {
        $this->ensureCategories();
        $rows = Expense::query()->with('expenseCategory')->get();

        return response()->json([
            'data' => [
                'total' => (int) $rows->sum('amount'),
                'count' => $rows->count(),
                'by_category' => $rows->groupBy(fn (Expense $expense) => $expense->expenseCategory?->name ?? $expense->category)
                    ->map(fn ($group, $name) => [
                        'name' => $name,
                        'total' => (int) $group->sum('amount'),
                        'count' => $group->count(),
                    ])->values(),
            ],
        ]);
    }

    public function report(Request $request): JsonResponse
    {
        return $this->dashboard();
    }

    public function recurring(): JsonResponse
    {
        return response()->json(['data' => []]);
    }

    public function storeRecurring(): JsonResponse
    {
        return response()->json(['message' => 'Les dépenses récurrentes ne sont pas utilisées.'], 422);
    }

    public function updateRecurring(): JsonResponse
    {
        return response()->json(['message' => 'Les dépenses récurrentes ne sont pas utilisées.'], 422);
    }

    public function generate(): JsonResponse
    {
        return response()->json(['data' => ['created' => 0]]);
    }

    public function rules(): JsonResponse
    {
        return response()->json(['data' => []]);
    }

    public function storeRule(): JsonResponse
    {
        return response()->json(['data' => []]);
    }

    public function budgets(): JsonResponse
    {
        return response()->json(['data' => []]);
    }

    public function storeBudget(): JsonResponse
    {
        return response()->json(['data' => []]);
    }

    public function submit(Expense $expense): JsonResponse
    {
        return response()->json(['data' => $expense]);
    }

    public function decide(Expense $expense): JsonResponse
    {
        return response()->json(['data' => $expense]);
    }

    public function pay(Expense $expense): JsonResponse
    {
        return response()->json(['data' => $expense]);
    }

    public function cancel(Expense $expense): JsonResponse
    {
        return response()->json(['data' => $expense]);
    }

    private function ensureCategories(): void
    {
        ExpenseCategory::ensureDefaults((string) app('tenant.id'));
    }
}
