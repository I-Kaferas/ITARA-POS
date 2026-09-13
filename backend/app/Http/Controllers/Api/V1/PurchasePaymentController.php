<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SupplierPaymentMethod;
use App\Http\Controllers\Controller;
use App\Models\PurchaseInvoice;
use App\Models\PurchasePayment;
use App\Services\Purchase\PurchasePaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PurchasePaymentController extends Controller
{
    public function __construct(
        private readonly PurchasePaymentService $paymentService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = PurchasePayment::query()
            ->with(['invoice:id,invoice_number,supplier_id,total,paid_amount,status', 'invoice.supplier:id,name'])
            ->orderByDesc('paid_at');

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function store(Request $request, PurchaseInvoice $purchaseInvoice): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'payment_method' => ['nullable', 'string'],
            'reference' => ['nullable', 'string', 'max:100'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $method = SupplierPaymentMethod::tryFrom($data['payment_method'] ?? '')
            ?? SupplierPaymentMethod::BankTransfer;

        $payment = $this->paymentService->record(
            invoice: $purchaseInvoice,
            amount: $data['amount'],
            method: $method,
            reference: $data['reference'] ?? null,
            notes: $data['notes'] ?? null,
            recordedBy: $request->user(),
        );

        return response()->json(['data' => $payment], 201);
    }
}
