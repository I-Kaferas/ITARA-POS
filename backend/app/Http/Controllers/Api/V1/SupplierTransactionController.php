<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SupplierTransactionType;
use App\Http\Controllers\Controller;
use App\Models\Supplier;
use App\Models\SupplierTransaction;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SupplierTransactionController extends Controller
{
    public function __construct(
        private readonly SupplierLedgerService $ledger,
    ) {}

    public function types(): JsonResponse
    {
        return response()->json([
            'data' => collect(SupplierTransactionType::cases())->map(fn ($t) => [
                'value' => $t->value,
                'increases_debt' => $t->increasesDebt(),
            ])->values(),
        ]);
    }

    public function index(Request $request, Supplier $supplier): JsonResponse
    {
        $query = SupplierTransaction::query()
            ->where('supplier_id', $supplier->id)
            ->with(['purchase:id,reference', 'supplierPayment:id,payment_number'])
            ->orderByDesc('occurred_at');

        if ($request->filled('transaction_type')) {
            $query->where('transaction_type', $request->string('transaction_type'));
        }

        return response()->json(['data' => $query->paginate($request->integer('per_page', 25))]);
    }

    public function store(Request $request, Supplier $supplier): JsonResponse
    {
        $payableTypes = [
            SupplierTransactionType::Purchase->value,
            SupplierTransactionType::DebitNote->value,
            SupplierTransactionType::OpeningBalance->value,
            SupplierTransactionType::Adjustment->value,
        ];

        $data = $request->validate([
            'transaction_type' => ['required', Rule::in($payableTypes)],
            'amount' => ['required', 'integer', 'min:1'],
            'reference' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
            'due_date' => ['nullable', 'date'],
            'occurred_at' => ['nullable', 'date'],
        ]);

        $transaction = $this->ledger->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::from($data['transaction_type']),
            'amount' => $data['amount'],
            'reference' => $data['reference'] ?? null,
            'description' => $data['description'] ?? null,
            'due_date' => $data['due_date'] ?? null,
            'occurred_at' => isset($data['occurred_at']) ? new \DateTimeImmutable($data['occurred_at']) : null,
            'recorded_by' => $request->user()?->id,
        ]);

        return response()->json(['data' => $transaction], 201);
    }

    public function storeCreditNote(Request $request, Supplier $supplier): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'reference' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
        ]);

        $transaction = $this->ledger->recordCreditNote(
            supplier: $supplier,
            amount: $data['amount'],
            reference: $data['reference'] ?? null,
            description: $data['description'] ?? null,
            recordedBy: $request->user()?->id,
        );

        return response()->json(['data' => $transaction], 201);
    }
}
