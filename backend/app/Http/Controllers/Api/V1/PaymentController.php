<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SalePaymentMethod;
use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\CompanyPaymentMethod;
use App\Models\PaymentTransaction;
use App\Models\Store;
use App\Services\Payments\CompanyPaymentMethodService;
use App\Services\Payments\PaymentEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PaymentController extends Controller
{
    public function __construct(
        private readonly PaymentEngine $paymentEngine,
        private readonly CompanyPaymentMethodService $paymentMethods,
    ) {}

    public function methods(Request $request): JsonResponse
    {
        $storeId = $request->string('store_id')->toString() ?: null;
        $companyId = $request->string('company_id')->toString() ?: null;
        $posOnly = $request->boolean('pos_only', true);

        $company = null;
        if ($storeId) {
            $store = Store::query()->with('branch.company')->find($storeId);
            $company = $store?->branch?->company;
        } elseif ($companyId) {
            $company = Company::query()->find($companyId);
        }

        if ($company) {
            $methods = $this->paymentMethods->forCompany(
                $company,
                enabledOnly: true,
                posOnly: $posOnly,
            );

            return response()->json([
                'data' => $methods->map(fn (CompanyPaymentMethod $m) => $m->toPosArray())->values(),
            ]);
        }

        // Fallback: catalog of all engine-supported methods (no company context).
        return response()->json([
            'data' => collect(SalePaymentMethod::cases())->map(fn (SalePaymentMethod $method) => [
                'value' => $method->value,
                'label' => $method->label(),
                'label_fr' => config("payments.methods.{$method->value}.label_fr"),
                'provider' => config("payments.methods.{$method->value}.provider"),
                'requires_customer' => $method->requiresCustomer(),
                'supports_change' => config("payments.methods.{$method->value}.supports_change", false),
            ])->values(),
        ]);
    }

    public function validatePayment(Request $request, Store $store): JsonResponse
    {
        $data = $this->validatePayload($request);

        $result = $this->paymentEngine->validate($store, $data);

        return response()->json(['data' => $result->toArray()]);
    }

    public function process(Request $request, Store $store): JsonResponse
    {
        $data = $this->validatePayload($request);

        $data['idempotency_key'] = $data['idempotency_key']
            ?? $request->header('Idempotency-Key');

        $result = $this->paymentEngine->process($store, $data, $request->user());

        return response()->json(['data' => $result->toArray()], 201);
    }

    public function show(PaymentTransaction $paymentTransaction): JsonResponse
    {
        $status = $this->paymentEngine->status($paymentTransaction);

        return response()->json([
            'data' => [
                ...$paymentTransaction->load(['store', 'customer', 'processedBy:id,name'])->toSummaryArray(),
                'status' => $status->value,
            ],
        ]);
    }

    /** @return array<string, mixed> */
    private function validatePayload(Request $request): array
    {
        return $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'cash_register_id' => ['nullable', 'uuid', 'exists:cash_registers,id'],
            'idempotency_key' => ['nullable', 'string', 'max:100'],
            'items.*.line_id' => ['nullable', 'string', 'max:120'],
            'items.*.product_id' => ['nullable', 'uuid', 'exists:products,id'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.unit_price' => ['nullable', 'integer', 'min:0'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.tax_rate' => ['nullable', 'numeric', 'min:0'],
            'items.*.tax_inclusive' => ['nullable', 'boolean'],
            'items.*.line_discount' => ['nullable', 'array'],
            'global_discount' => ['nullable', 'array'],
            'fees' => ['nullable', 'array'],
            'apply_promotions' => ['nullable', 'boolean'],
            'payments' => ['required', 'array', 'min:1'],
            'payments.*.method' => ['required', Rule::in(SalePaymentMethod::values())],
            'payments.*.amount' => ['required', 'integer', 'min:1'],
            'payments.*.metadata' => ['nullable', 'array'],
        ]);
    }
}
