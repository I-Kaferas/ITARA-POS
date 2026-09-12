<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SupplierPaymentMethod;
use App\Http\Controllers\Controller;
use App\Models\Supplier;
use App\Models\SupplierPayment;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SupplierPaymentController extends Controller
{
    public function __construct(
        private readonly SupplierLedgerService $ledger,
    ) {}

    public function methods(): JsonResponse
    {
        return response()->json([
            'data' => collect(SupplierPaymentMethod::cases())->map(fn ($m) => [
                'value' => $m->value,
            ])->values(),
        ]);
    }

    public function index(Request $request, Supplier $supplier): JsonResponse
    {
        $query = $supplier->payments()->with('recordedBy:id,name');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json(['data' => $query->paginate($request->integer('per_page', 25))]);
    }

    public function show(SupplierPayment $supplierPayment): JsonResponse
    {
        return response()->json([
            'data' => $supplierPayment->load(['supplier', 'recordedBy:id,name', 'transactions']),
        ]);
    }

    public function store(Request $request, Supplier $supplier): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'payment_method' => ['nullable', Rule::in(SupplierPaymentMethod::values())],
            'reference' => ['nullable', 'string', 'max:100'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'paid_at' => ['nullable', 'date'],
            'allocations' => ['nullable', 'array'],
            'allocations.*.transaction_id' => ['required_with:allocations', 'uuid', 'exists:supplier_transactions,id'],
            'allocations.*.amount' => ['required_with:allocations', 'integer', 'min:1'],
        ]);

        $payment = $this->ledger->recordPayment(
            supplier: $supplier,
            amount: $data['amount'],
            method: isset($data['payment_method'])
                ? SupplierPaymentMethod::from($data['payment_method'])
                : SupplierPaymentMethod::BankTransfer,
            allocations: $data['allocations'] ?? null,
            reference: $data['reference'] ?? null,
            notes: $data['notes'] ?? null,
            recordedBy: $request->user()?->id,
            paidAt: isset($data['paid_at']) ? new \DateTimeImmutable($data['paid_at']) : null,
        );

        return response()->json(['data' => $payment], 201);
    }
}
