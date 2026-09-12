<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SalePaymentMethod;
use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\CompanyPaymentMethod;
use App\Services\Payments\CompanyPaymentMethodService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CompanyPaymentMethodController extends Controller
{
    public function __construct(
        private readonly CompanyPaymentMethodService $service,
    ) {}

    public function index(Request $request, Company $company): JsonResponse
    {
        $methods = $this->service->forCompany(
            $company,
            enabledOnly: $request->boolean('enabled_only'),
            posOnly: $request->boolean('pos_only'),
        );

        return response()->json([
            'data' => $methods->map(fn (CompanyPaymentMethod $m) => $m->toPosArray())->values(),
        ]);
    }

    public function update(Request $request, Company $company, CompanyPaymentMethod $paymentMethod): JsonResponse
    {
        if ($paymentMethod->company_id !== $company->id) {
            abort(404);
        }

        $data = $request->validate([
            'label' => ['sometimes', 'string', 'max:100'],
            'label_fr' => ['nullable', 'string', 'max:100'],
            'is_enabled' => ['sometimes', 'boolean'],
            'available_on_pos' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer', 'min:0', 'max:9999'],
            'config' => ['nullable', 'array'],
        ]);

        if (array_key_exists('available_on_pos', $data) && ($data['available_on_pos'] ?? false) === true) {
            $data['is_enabled'] = true;
        }

        $paymentMethod->update($data);

        return response()->json(['data' => $paymentMethod->fresh()->toPosArray()]);
    }

    public function reorder(Request $request, Company $company): JsonResponse
    {
        $data = $request->validate([
            'order' => ['required', 'array', 'min:1'],
            'order.*' => ['uuid', Rule::exists('company_payment_methods', 'id')->where('company_id', $company->id)],
        ]);

        foreach ($data['order'] as $index => $id) {
            CompanyPaymentMethod::query()
                ->where('company_id', $company->id)
                ->whereKey($id)
                ->update(['sort_order' => $index * 10]);
        }

        $methods = $this->service->forCompany($company);

        return response()->json([
            'data' => $methods->map(fn (CompanyPaymentMethod $m) => $m->toPosArray())->values(),
        ]);
    }

    public function catalog(): JsonResponse
    {
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
}
