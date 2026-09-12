<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\CustomerPaymentMethod;
use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Services\Customer\CustomerLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CustomerPaymentController extends Controller
{
    public function __construct(
        private readonly CustomerLedgerService $ledger,
    ) {}

    public function methods(): JsonResponse
    {
        return response()->json([
            'data' => collect(CustomerPaymentMethod::cases())->map(fn ($m) => [
                'value' => $m->value,
            ])->values(),
        ]);
    }

    public function index(Request $request, Customer $customer): JsonResponse
    {
        $query = $customer->payments()->with('recordedBy:id,name');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json(['data' => $query->paginate($request->integer('per_page', 25))]);
    }

    public function show(CustomerPayment $customerPayment): JsonResponse
    {
        return response()->json([
            'data' => $customerPayment->load(['customer', 'recordedBy:id,name', 'transactions']),
        ]);
    }

    public function store(Request $request, Customer $customer): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'payment_method' => ['nullable', Rule::in(CustomerPaymentMethod::values())],
            'reference' => ['nullable', 'string', 'max:100'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'paid_at' => ['nullable', 'date'],
            'allocations' => ['nullable', 'array'],
            'allocations.*.transaction_id' => ['required_with:allocations', 'uuid', 'exists:customer_transactions,id'],
            'allocations.*.amount' => ['required_with:allocations', 'integer', 'min:1'],
        ]);

        $payment = $this->ledger->recordPayment(
            customer: $customer,
            amount: $data['amount'],
            method: isset($data['payment_method'])
                ? CustomerPaymentMethod::from($data['payment_method'])
                : CustomerPaymentMethod::Cash,
            allocations: $data['allocations'] ?? null,
            reference: $data['reference'] ?? null,
            notes: $data['notes'] ?? null,
            recordedBy: $request->user()?->id,
            paidAt: isset($data['paid_at']) ? new \DateTimeImmutable($data['paid_at']) : null,
        );

        return response()->json(['data' => $payment], 201);
    }
}
