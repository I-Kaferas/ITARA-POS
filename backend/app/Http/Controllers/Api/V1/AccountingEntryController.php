<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AccountingEntryType;
use App\Http\Controllers\Controller;
use App\Models\AccountingEntry;
use App\Services\Accounting\AccountingBooksService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class AccountingEntryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = AccountingEntry::query()
            ->with(['recordedByUser:id,name'])
            ->orderByDesc('occurred_at');

        if ($request->filled('entry_type')) {
            $query->where('entry_type', $request->string('entry_type'));
        }

        if ($request->filled('account_code')) {
            $query->where('account_code', $request->string('account_code'));
        }

        if ($request->filled('reference_type')) {
            $query->where('reference_type', $request->string('reference_type'));
        }

        if ($request->filled('from')) {
            $query->where('occurred_at', '>=', $request->date('from')->startOfDay());
        }

        if ($request->filled('to')) {
            $query->where('occurred_at', '<=', $request->date('to')->endOfDay());
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function show(AccountingEntry $accountingEntry): JsonResponse
    {
        return response()->json([
            'data' => $accountingEntry->load(['recordedByUser:id,name']),
        ]);
    }

    public function types(): JsonResponse
    {
        return response()->json([
            'data' => collect(AccountingEntryType::cases())->map(fn (AccountingEntryType $type) => [
                'value' => $type->value,
                'label' => str_replace('_', ' ', ucfirst($type->value)),
            ])->values(),
        ]);
    }

    public function summary(Request $request, AccountingBooksService $books): JsonResponse
    {
        $query = AccountingEntry::query();

        if ($request->filled('from')) {
            $query->where('occurred_at', '>=', $request->date('from')->startOfDay());
        }

        if ($request->filled('to')) {
            $query->where('occurred_at', '<=', $request->date('to')->endOfDay());
        }

        $byAccount = (clone $query)
            ->select('account_code', DB::raw('SUM(debit) as total_debit'), DB::raw('SUM(credit) as total_credit'))
            ->groupBy('account_code')
            ->orderBy('account_code')
            ->get()
            ->map(fn ($row) => [
                'account_code' => $row->account_code,
                'total_debit' => (int) $row->total_debit,
                'total_credit' => (int) $row->total_credit,
                'balance' => (int) $row->total_debit - (int) $row->total_credit,
            ]);

        $totals = [
            'total_debit' => (int) (clone $query)->sum('debit'),
            'total_credit' => (int) (clone $query)->sum('credit'),
            'entries_count' => (clone $query)->count(),
        ];

        $tenantId = (string) $request->user()?->tenant_id;

        return response()->json([
            'data' => [
                'totals' => $totals,
                'by_account' => $byAccount,
                'books' => $tenantId === '' ? [] : $books->books(
                    $tenantId,
                    $request->filled('from') ? $request->string('from')->toString() : null,
                    $request->filled('to') ? $request->string('to')->toString() : null,
                ),
            ],
        ]);
    }

    public function storeManual(Request $request): JsonResponse
    {
        $data = $request->validate([
            'entry_type' => ['required', Rule::in(AccountingEntryType::values())],
            'reference_type' => ['required', 'string', 'max:100'],
            'reference_id' => ['required', 'uuid'],
            'debit' => ['required', 'integer', 'min:0'],
            'credit' => ['required', 'integer', 'min:0'],
            'account_code' => ['nullable', 'string', 'max:30'],
            'description' => ['nullable', 'string', 'max:2000'],
            'occurred_at' => ['nullable', 'date'],
        ]);

        if (($data['debit'] === 0 && $data['credit'] === 0) || ($data['debit'] > 0 && $data['credit'] > 0)) {
            return response()->json([
                'message' => 'Provide either debit or credit (not both, not neither).',
            ], 422);
        }

        $entry = AccountingEntry::query()->create([
            'tenant_id' => app('tenant.id'),
            'entry_type' => $data['entry_type'],
            'reference_type' => $data['reference_type'],
            'reference_id' => $data['reference_id'],
            'debit' => $data['debit'],
            'credit' => $data['credit'],
            'account_code' => $data['account_code'] ?? null,
            'description' => $data['description'] ?? null,
            'recorded_by' => $request->user()?->id,
            'occurred_at' => $data['occurred_at'] ?? now(),
        ]);

        return response()->json(['data' => $entry], 201);
    }
}
