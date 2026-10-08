<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\TransactionPaymentStatus;
use App\Enums\TransactionStatus;
use App\Enums\TransactionType;
use App\Http\Controllers\Controller;
use App\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TransactionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Transaction::query()
            ->with(['branch:id,name,code', 'user:id,name'])
            ->orderByDesc('date')
            ->orderByDesc('created_at');

        if ($request->filled('type')) {
            $query->where('type', $request->string('type'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        if ($request->filled('payment_status')) {
            $query->where('payment_status', $request->string('payment_status'));
        }

        if ($request->filled('branch_id')) {
            $query->where('branch_id', $request->string('branch_id'));
        }

        if ($request->filled('user_id')) {
            $query->where('user_id', $request->string('user_id'));
        }

        if ($request->filled('from')) {
            $query->where('date', '>=', $request->date('from')->toDateString());
        }

        if ($request->filled('to')) {
            $query->where('date', '<=', $request->date('to')->toDateString());
        }

        if ($request->filled('reference')) {
            $query->where('reference', 'like', '%'.$request->string('reference').'%');
        }

        $paginator = $query->paginate($request->pageSize());

        return response()->json([
            'data' => $paginator->getCollection()->map(fn (Transaction $tx) => $tx->toSummaryArray())->values(),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function show(Transaction $transaction): JsonResponse
    {
        return response()->json([
            'data' => $transaction->load(['branch:id,name,code', 'user:id,name', 'source'])->toSummaryArray(),
        ]);
    }

    public function types(): JsonResponse
    {
        return response()->json([
            'data' => [
                'types' => collect(TransactionType::cases())->map(fn (TransactionType $type) => [
                    'value' => $type->value,
                    'label' => ucfirst($type->value),
                ])->values(),
                'statuses' => collect(TransactionStatus::cases())->map(fn (TransactionStatus $status) => [
                    'value' => $status->value,
                    'label' => ucfirst($status->value),
                ])->values(),
                'payment_statuses' => collect(TransactionPaymentStatus::cases())->map(fn (TransactionPaymentStatus $status) => [
                    'value' => $status->value,
                    'label' => str_replace('_', ' ', ucfirst($status->value)),
                ])->values(),
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(TransactionType::values())],
            'amount' => ['required', 'integer'],
            'currency' => ['nullable', 'string', 'size:3'],
            'branch_id' => ['nullable', 'uuid', 'exists:branches,id'],
            'user_id' => ['nullable', 'uuid', 'exists:users,id'],
            'reference' => ['nullable', 'string', 'max:40'],
            'date' => ['nullable', 'date'],
            'status' => ['nullable', Rule::in(TransactionStatus::values())],
            'payment_status' => ['nullable', Rule::in(TransactionPaymentStatus::values())],
            'metadata' => ['nullable', 'array'],
        ]);

        $tenant = $request->attributes->get('tenant');

        $transaction = app(\App\Services\Transactions\TransactionEngine::class)->recordFromArray([
            ...$data,
            'tenant_id' => $tenant->id,
            'user_id' => $data['user_id'] ?? $request->user()?->id,
        ]);

        return response()->json([
            'data' => $transaction->load(['branch:id,name,code', 'user:id,name'])->toSummaryArray(),
        ], 201);
    }
}
