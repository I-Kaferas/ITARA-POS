<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\Expense;
use App\Models\ExpenseCategory;
use App\Models\RecurringExpense;
use App\Models\User;
use App\Services\Expenses\ExpenseService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

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

        if ($request->filled('q')) {
            $term = '%'.$request->string('q').'%';
            $query->where(function ($builder) use ($term) {
                $builder->where('description', 'like', $term)
                    ->orWhere('notes', 'like', $term)
                    ->orWhere('reference', 'like', $term)
                    ->orWhereHas('expenseCategory', fn ($category) => $category->where('name', 'like', $term));
            });
        }

        if ($request->filled('from')) {
            $query->whereDate('occurred_on', '>=', $request->date('from'));
        }

        if ($request->filled('to')) {
            $query->whereDate('occurred_on', '<=', $request->date('to'));
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
            'color' => ['nullable', 'string', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'description' => ['nullable', 'string', 'max:500'],
        ]);

        $category = ExpenseCategory::query()->create([
            'tenant_id' => app('tenant.id'),
            'name' => $data['name'],
            'code' => $data['code'] ?? str($data['name'])->slug('_')->limit(40, '')->toString(),
            'color' => $data['color'] ?? '#6366F1',
            'description' => $data['description'] ?? null,
            'is_active' => true,
            'sort_order' => 100,
        ]);

        return response()->json(['data' => $category], 201);
    }

    public function updateCategory(Request $request, ExpenseCategory $expenseCategory): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'color' => ['sometimes', 'nullable', 'string', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $expenseCategory->update($data);

        return response()->json(['data' => $expenseCategory]);
    }

    public function dashboard(Request $request): JsonResponse
    {
        $this->ensureCategories();
        $query = Expense::query()->with('expenseCategory')->where('status', 'paid');

        if ($request->filled('from')) {
            $query->whereDate('occurred_on', '>=', $request->date('from'));
        }

        if ($request->filled('to')) {
            $query->whereDate('occurred_on', '<=', $request->date('to'));
        }

        if ($request->filled('expense_category_id')) {
            $query->where('expense_category_id', $request->string('expense_category_id'));
        }

        $rows = $query->get();

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
        $this->ensureCategories();

        $query = Expense::query()->with([
            'expenseCategory:id,name',
            'cashRegisterSession.register:id,name',
        ]);

        if ($request->filled('from')) {
            $query->whereDate('occurred_on', '>=', $request->date('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('occurred_on', '<=', $request->date('to'));
        }

        $rows = $query->get();
        $total = (int) $rows->sum('amount');
        $count = $rows->count();

        $group = function ($collection, callable $keyOf) {
            return $collection->groupBy($keyOf)->map(function ($group, $key) {
                return [
                    'key' => (string) $key,
                    'total' => (int) $group->sum('amount'),
                    'count' => $group->count(),
                ];
            })->sortBy('key')->values();
        };

        return response()->json([
            'data' => [
                'total' => $total,
                'count' => $count,
                'average' => $count > 0 ? (int) round($total / $count) : 0,
                'active_categories' => $rows->pluck('expense_category_id')->filter()->unique()->count(),
                'monthly' => $group($rows, fn (Expense $expense) => $expense->occurred_on?->format('Y-m') ?? 'unknown'),
                'yearly' => $group($rows, fn (Expense $expense) => $expense->occurred_on?->format('Y') ?? 'unknown'),
                'by_category' => $rows
                    ->groupBy(fn (Expense $expense) => $expense->expenseCategory?->name ?: ($expense->category ?: 'other'))
                    ->map(fn ($group, $name) => [
                        'key' => (string) $name,
                        'total' => (int) $group->sum('amount'),
                        'count' => $group->count(),
                    ])
                    ->sortByDesc('total')
                    ->values(),
                'by_fund' => $rows
                    ->groupBy(fn (Expense $expense) => $expense->cashRegisterSession?->register?->name ?: 'none')
                    ->map(fn ($group, $name) => [
                        'key' => (string) $name,
                        'total' => (int) $group->sum('amount'),
                        'count' => $group->count(),
                    ])
                    ->sortByDesc('total')
                    ->values(),
            ],
        ]);
    }

    public function recurring(): JsonResponse
    {
        $rows = RecurringExpense::query()
            ->with(['expenseCategory:id,name', 'cashRegister:id,name', 'user:id,name'])
            ->orderBy('next_due_on')
            ->orderBy('name')
            ->get();

        return response()->json(['data' => $rows]);
    }

    public function storeRecurring(Request $request): JsonResponse
    {
        $data = $this->validateRecurring($request);
        $row = RecurringExpense::query()->create($data);

        return response()->json([
            'data' => $row->load(['expenseCategory:id,name', 'cashRegister:id,name', 'user:id,name']),
        ], 201);
    }

    public function updateRecurring(Request $request, RecurringExpense $recurringExpense): JsonResponse
    {
        $data = $this->validateRecurring($request, $recurringExpense);
        $recurringExpense->update($data);

        return response()->json([
            'data' => $recurringExpense->fresh(['expenseCategory:id,name', 'cashRegister:id,name', 'user:id,name']),
        ]);
    }

    public function generate(Request $request): JsonResponse
    {
        $created = 0;
        $due = RecurringExpense::query()
            ->where('is_active', true)
            ->whereDate('next_due_on', '<=', now()->toDateString())
            ->get();

        foreach ($due as $row) {
            $branchId = $row->branch_id ?: Branch::query()->where('tenant_id', $row->tenant_id)->orderBy('created_at')->value('id');
            if (! $branchId || ! $row->expense_category_id) {
                continue;
            }

            $this->expenses->record([
                'branch_id' => $branchId,
                'store_id' => $row->store_id,
                'expense_category_id' => $row->expense_category_id,
                'description' => $row->name,
                'amount' => (int) $row->amount,
                'user_id' => $row->user_id,
                'occurred_on' => $row->next_due_on?->toDateString(),
                'notes' => $row->notes,
                'currency_code' => $row->currency_code,
            ], $request->user());

            $next = $this->followingDate(
                $row->next_due_on?->toDateString() ?? now()->toDateString(),
                (string) $row->frequency,
                $row->ends_on?->toDateString(),
            );
            $row->update($next === null
                ? ['is_active' => false]
                : ['next_due_on' => $next]);
            $created++;
        }

        return response()->json(['data' => ['created' => $created]]);
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
        $this->assertTransition($expense, ['draft']);
        $expense->update(['status' => 'submitted']);

        return response()->json(['data' => $this->presentExpense($expense)]);
    }

    public function decide(Request $request, Expense $expense): JsonResponse
    {
        $data = $request->validate([
            'decision' => ['required', 'string', Rule::in(['approved', 'rejected'])],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);
        $this->assertTransition($expense, ['submitted']);
        $expense->update([
            'status' => $data['decision'] === 'approved' ? 'approved' : 'rejected',
            'decision' => $data['decision'],
            'decision_comment' => $data['comment'] ?? null,
            'decided_at' => now(),
        ]);

        return response()->json(['data' => $this->presentExpense($expense)]);
    }

    public function pay(Request $request, Expense $expense): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'payment_method' => ['required', 'string', 'max:40'],
            'reference' => ['nullable', 'string', 'max:80'],
            'idempotency_key' => ['nullable', 'string', 'max:80'],
        ]);
        $this->assertTransition($expense, ['approved']);
        $paid = $this->expenses->pay($expense->load(['branch', 'expenseCategory']), $request->user(), $data);

        return response()->json(['data' => $paid]);
    }

    public function cancel(Expense $expense): JsonResponse
    {
        $this->assertTransition($expense, ['draft', 'submitted', 'approved']);
        $expense->update(['status' => 'cancelled']);

        return response()->json(['data' => $this->presentExpense($expense)]);
    }

    /** @param  list<string>  $allowed */
    private function assertTransition(Expense $expense, array $allowed): void
    {
        if (! in_array($expense->status, $allowed, true)) {
            throw ValidationException::withMessages([
                'status' => ["Cette dépense ne peut pas passer de « {$expense->status} » à l'étape demandée."],
            ]);
        }
    }

    private function presentExpense(Expense $expense): Expense
    {
        return $expense->fresh(['expenseCategory', 'branch', 'user', 'cashRegisterSession.register']);
    }

    /**
     * @return array<string, mixed>
     */
    private function validateRecurring(Request $request, ?RecurringExpense $existing = null): array
    {
        $data = $request->validate([
            'name' => [$existing ? 'sometimes' : 'required', 'string', 'max:255'],
            'amount' => [$existing ? 'sometimes' : 'required', 'integer', 'min:1'],
            'fund_source' => [$existing ? 'sometimes' : 'required', 'string', Rule::in(['operating', 'social', 'main'])],
            'expense_category_id' => [$existing ? 'sometimes' : 'required', 'uuid'],
            'user_id' => ['nullable', 'uuid'],
            'starts_on' => [$existing ? 'sometimes' : 'required', 'date'],
            'ends_on' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'is_active' => ['sometimes', 'boolean'],
            'frequency' => [$existing ? 'sometimes' : 'required', 'string', Rule::in(['daily', 'weekly', 'monthly', 'quarterly', 'yearly'])],
            'currency_code' => ['nullable', 'string', 'size:3'],
        ]);

        if (array_key_exists('expense_category_id', $data)) {
            $category = ExpenseCategory::query()->find($data['expense_category_id']);
            if (! $category) {
                throw ValidationException::withMessages([
                    'expense_category_id' => ['La catégorie est introuvable.'],
                ]);
            }
        }

        if (array_key_exists('user_id', $data) && $data['user_id']) {
            if (! User::query()->whereKey($data['user_id'])->exists()) {
                throw ValidationException::withMessages([
                    'user_id' => ['Le responsable est introuvable.'],
                ]);
            }
        }

        $starts = $data['starts_on'] ?? $existing?->starts_on?->toDateString();
        $ends = array_key_exists('ends_on', $data)
            ? ($data['ends_on'] ?: null)
            : $existing?->ends_on?->toDateString();
        if ($starts && $ends && Carbon::parse($ends)->lt(Carbon::parse($starts))) {
            throw ValidationException::withMessages([
                'ends_on' => ['La date de fin doit être postérieure à la date de début.'],
            ]);
        }

        $scheduleTouched = ! $existing
            || isset($data['starts_on'])
            || isset($data['frequency'])
            || array_key_exists('ends_on', $data);
        if ($scheduleTouched && $starts) {
            $frequency = $data['frequency'] ?? $existing?->frequency ?? 'monthly';
            $next = $this->nextOccurrence($starts, $frequency, $ends);
            if ($next === null) {
                $data['is_active'] = false;
                $data['next_due_on'] = $ends ?? $starts;
            } else {
                $data['next_due_on'] = $next;
            }
        }

        if (! $existing) {
            $data['frequency'] ??= 'monthly';
            $data['is_active'] = $data['is_active'] ?? true;
            $data['currency_code'] = strtoupper((string) ($data['currency_code'] ?: 'BIF'));
        } elseif (isset($data['currency_code'])) {
            $data['currency_code'] = strtoupper((string) $data['currency_code']);
        }

        return $data;
    }

    private function nextOccurrence(string $startsOn, string $frequency, ?string $endsOn): ?string
    {
        $date = Carbon::parse($startsOn)->startOfDay();
        $today = now()->startOfDay();
        $end = $endsOn ? Carbon::parse($endsOn)->startOfDay() : null;

        for ($guard = 0; $date->lt($today) && $guard < 600; $guard++) {
            $date = match ($frequency) {
                'daily' => $date->copy()->addDay(),
                'weekly' => $date->copy()->addWeek(),
                'quarterly' => $date->copy()->addMonths(3),
                'yearly' => $date->copy()->addYear(),
                default => $date->copy()->addMonth(),
            };
        }

        if ($end && $date->gt($end)) {
            return null;
        }

        return $date->toDateString();
    }

    private function followingDate(string $from, string $frequency, ?string $endsOn): ?string
    {
        $date = Carbon::parse($from)->startOfDay();
        $date = match ($frequency) {
            'daily' => $date->addDay(),
            'weekly' => $date->addWeek(),
            'quarterly' => $date->addMonths(3),
            'yearly' => $date->addYear(),
            default => $date->addMonth(),
        };
        if ($endsOn && $date->gt(Carbon::parse($endsOn)->startOfDay())) {
            return null;
        }

        return $date->toDateString();
    }

    private function ensureCategories(): void
    {
        ExpenseCategory::ensureDefaults((string) app('tenant.id'));
    }
}
