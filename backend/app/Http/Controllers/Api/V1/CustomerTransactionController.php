<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\CustomerTransactionType;
use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\CustomerTransaction;
use App\Services\Customer\CustomerLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CustomerTransactionController extends Controller
{
    public function __construct(
        private readonly CustomerLedgerService $ledger,
    ) {}

    public function types(): JsonResponse
    {
        return response()->json([
            'data' => collect(CustomerTransactionType::cases())->map(fn ($t) => [
                'value' => $t->value,
                'increases_receivable' => $t->increasesReceivable(),
            ])->values(),
        ]);
    }

    public function index(Request $request, Customer $customer): JsonResponse
    {
        $query = CustomerTransaction::query()
            ->where('customer_id', $customer->id)
            ->with(['sale:id,reference', 'customerPayment:id,payment_number'])
            ->orderByDesc('occurred_at');

        if ($request->filled('transaction_type')) {
            $query->where('transaction_type', $request->string('transaction_type'));
        }

        return response()->json(['data' => $query->paginate($request->integer('per_page', 25))]);
    }

    public function store(Request $request, Customer $customer): JsonResponse
    {
        $types = [
            CustomerTransactionType::Sale->value,
            CustomerTransactionType::OpeningBalance->value,
            CustomerTransactionType::Adjustment->value,
        ];

        $data = $request->validate([
            'transaction_type' => ['required', Rule::in($types)],
            'amount' => ['required', 'integer', 'min:1'],
            'reference' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
            'due_date' => ['nullable', 'date'],
            'occurred_at' => ['nullable', 'date'],
            'earn_loyalty' => ['boolean'],
        ]);

        $transaction = $this->ledger->recordReceivable($customer, [
            'transaction_type' => CustomerTransactionType::from($data['transaction_type']),
            'amount' => $data['amount'],
            'reference' => $data['reference'] ?? null,
            'description' => $data['description'] ?? null,
            'due_date' => $data['due_date'] ?? null,
            'occurred_at' => isset($data['occurred_at']) ? new \DateTimeImmutable($data['occurred_at']) : null,
            'recorded_by' => $request->user()?->id,
            'earn_loyalty' => $data['earn_loyalty'] ?? true,
        ]);

        return response()->json(['data' => $transaction], 201);
    }

    public function storeSaleReturn(Request $request, Customer $customer): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'reference' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
        ]);

        $transaction = $this->ledger->recordSaleReturn(
            customer: $customer,
            amount: $data['amount'],
            reference: $data['reference'] ?? null,
            description: $data['description'] ?? null,
            recordedBy: $request->user()?->id,
        );

        return response()->json(['data' => $transaction], 201);
    }

    public function storeCreditNote(Request $request, Customer $customer): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'reference' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
        ]);

        $transaction = $this->ledger->recordCreditNote(
            customer: $customer,
            amount: $data['amount'],
            reference: $data['reference'] ?? null,
            description: $data['description'] ?? null,
            recordedBy: $request->user()?->id,
        );

        return response()->json(['data' => $transaction], 201);
    }
}
