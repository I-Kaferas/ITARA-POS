<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SalePaymentStatus;
use App\Enums\SaleStatus;
use App\Http\Controllers\Controller;
use App\Models\Sale;
use App\Models\Store;
use App\Services\Payments\CompanyPaymentMethodService;
use App\Services\Sales\SaleEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\StreamedResponse;

class SaleController extends Controller
{
    public function __construct(
        private readonly SaleEngine $saleEngine,
        private readonly CompanyPaymentMethodService $paymentMethods,
    ) {}

    public function index(Request $request, Store $store): JsonResponse
    {
        $filters = $this->validatedListFilters($request);

        $sales = $this->saleEngine->listForStore($store, $filters);

        return response()->json([
            'data' => $sales->map(fn (Sale $sale) => $sale->toSummaryArray())->values(),
            'meta' => [
                'count' => $sales->count(),
                'limit' => (int) ($filters['limit'] ?? 50),
                'filters' => [
                    'q' => $filters['q'] ?? null,
                    'status' => $filters['status'] ?? null,
                    'payment_status' => $filters['payment_status'] ?? null,
                    'customer_id' => $filters['customer_id'] ?? null,
                    'from' => $filters['from'] ?? null,
                    'to' => $filters['to'] ?? null,
                ],
            ],
        ]);
    }

    public function export(Request $request, Store $store): StreamedResponse
    {
        $filters = $this->validatedListFilters($request, forExport: true);
        $query = $this->saleEngine->queryForStore($store, $filters);

        $filename = 'commandes-'.$store->code.'-'.now()->format('Ymd-His').'.csv';

        return response()->streamDownload(function () use ($query) {
            $out = fopen('php://output', 'w');
            fprintf($out, chr(0xEF).chr(0xBB).chr(0xBF));
            fputcsv($out, [
                'reference',
                'date',
                'customer',
                'status',
                'payment_status',
                'cashier',
                'subtotal',
                'tax',
                'discount',
                'total',
                'paid',
                'currency',
                'notes',
            ], ';');

            foreach ($query->cursor() as $sale) {
                fputcsv($out, [
                    $sale->reference,
                    ($sale->completed_at ?? $sale->created_at)?->toDateTimeString(),
                    $sale->customer?->name,
                    $sale->status?->value ?? $sale->status,
                    $sale->payment_status?->value ?? $sale->payment_status,
                    $sale->processedBy?->name,
                    number_format(($sale->subtotal ?? 0) / 100, 2, '.', ''),
                    number_format(($sale->tax_total ?? 0) / 100, 2, '.', ''),
                    number_format(($sale->discount_total ?? 0) / 100, 2, '.', ''),
                    number_format(($sale->total ?? 0) / 100, 2, '.', ''),
                    number_format(($sale->paid_amount ?? 0) / 100, 2, '.', ''),
                    $sale->currency,
                    $sale->notes,
                ], ';');
            }

            fclose($out);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    public function store(Request $request, Store $store): JsonResponse
    {
        $data = $this->paymentMethods->normalizePaymentPayload($store, $this->validatePayload($request));

        $data['idempotency_key'] = $data['idempotency_key']
            ?? $request->header('Idempotency-Key');

        if (! empty($data['sale_id'])) {
            $result = $this->saleEngine->completePending($store, $data, $request->user());
        } else {
            $result = $this->saleEngine->create($store, $data, $request->user());
        }

        return response()->json(['data' => $result->toArray()], 201);
    }

    public function hold(Request $request, Store $store): JsonResponse
    {
        $data = $this->validateHoldPayload($request);
        $sale = $this->saleEngine->hold($store, $data, $request->user());

        return response()->json(['data' => $this->salePayload($sale)], 201);
    }

    public function update(Request $request, Sale $sale): JsonResponse
    {
        $data = $this->validateHoldPayload($request);
        $sale = $this->saleEngine->updateHold($sale, $data, $request->user());

        return response()->json(['data' => $this->salePayload($sale)]);
    }

    public function destroy(Request $request, Sale $sale): JsonResponse
    {
        $this->saleEngine->discardHold($sale, $request->user());

        return response()->json(['data' => ['deleted' => true]]);
    }

    public function show(Sale $sale): JsonResponse
    {
        $sale = $this->saleEngine->find($sale->id);

        return response()->json([
            'data' => [
                ...$sale->toSummaryArray(),
                'items' => $sale->items,
                'payments' => $sale->payments->load('paymentTransaction'),
                'taxes' => $sale->taxes,
                'discounts' => $sale->discounts,
                'installments' => $sale->installments,
                'paid_amount' => $sale->paid_amount,
                'outstanding_amount' => $sale->outstandingAmount(),
                'due_date' => $sale->due_date?->toDateString(),
                'payment_status' => $sale->payment_status->value,
                'notes' => $sale->notes,
                'customer' => $sale->customer?->only(['id', 'name', 'email']),
                'processed_by' => $sale->processedBy?->only(['id', 'name']),
            ],
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function validatedListFilters(Request $request, bool $forExport = false): array
    {
        $maxLimit = $forExport ? 5000 : 200;

        return $request->validate([
            'limit' => ['sometimes', 'integer', 'min:1', 'max:'.$maxLimit],
            'q' => ['nullable', 'string', 'max:120'],
            'status' => ['nullable', 'string', Rule::in(SaleStatus::values())],
            'payment_status' => ['nullable', 'string', Rule::in(SalePaymentStatus::values())],
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ]);
    }

    /** @return array<string, mixed> */
    private function validatePayload(Request $request): array
    {
        return $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
            'cash_register_id' => ['nullable', 'uuid', 'exists:cash_registers,id'],
            'cashier_shift_id' => ['nullable', 'uuid', 'exists:cashier_shifts,id'],
            'device_id' => ['nullable', 'uuid', 'exists:devices,id'],
            'idempotency_key' => ['nullable', 'string', 'max:100'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'items.*.line_id' => ['nullable', 'string', 'max:120'],
            'items.*.product_id' => ['nullable', 'uuid', 'exists:products,id'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.sale_unit_id' => ['nullable', 'uuid', 'exists:product_sale_units,id'],
            'items.*.unit_price' => ['nullable', 'integer', 'min:0'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.tax_rate' => ['nullable', 'numeric', 'min:0'],
            'items.*.tax_inclusive' => ['nullable', 'boolean'],
            'items.*.line_discount' => ['nullable', 'array'],
            'global_discount' => ['nullable', 'array'],
            'fees' => ['nullable', 'array'],
            'apply_promotions' => ['nullable', 'boolean'],
            'payments' => ['required', 'array', 'min:1'],
            'payments.*.method' => ['required', 'string', 'max:30'],
            'payments.*.amount' => ['required', 'integer', 'min:1'],
            'payments.*.metadata' => ['nullable', 'array'],
            'due_date' => ['nullable', 'date'],
            'installments' => ['nullable', 'array'],
            'installments.count' => ['nullable', 'integer', 'min:1', 'max:60'],
            'installments.first_due_date' => ['nullable', 'date'],
            'installments.schedule' => ['nullable', 'array', 'min:1'],
            'installments.schedule.*.amount' => ['required_with:installments.schedule', 'integer', 'min:1'],
            'installments.schedule.*.due_date' => ['required_with:installments.schedule', 'date'],
            'sale_id' => ['nullable', 'uuid', 'exists:sales,id'],
        ]);
    }

    /** @return array<string, mixed> */
    private function validateHoldPayload(Request $request): array
    {
        return $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
            'cash_register_id' => ['nullable', 'uuid', 'exists:cash_registers,id'],
            'cashier_shift_id' => ['nullable', 'uuid', 'exists:cashier_shifts,id'],
            'device_id' => ['nullable', 'uuid', 'exists:devices,id'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'items.*.line_id' => ['nullable', 'string', 'max:120'],
            'items.*.product_id' => ['nullable', 'uuid', 'exists:products,id'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.sale_unit_id' => ['nullable', 'uuid', 'exists:product_sale_units,id'],
            'items.*.unit_price' => ['nullable', 'integer', 'min:0'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.tax_rate' => ['nullable', 'numeric', 'min:0'],
            'items.*.tax_inclusive' => ['nullable', 'boolean'],
            'items.*.line_discount' => ['nullable', 'array'],
            'global_discount' => ['nullable', 'array'],
            'fees' => ['nullable', 'array'],
            'apply_promotions' => ['nullable', 'boolean'],
        ]);
    }

    /** @return array<string, mixed> */
    private function salePayload(Sale $sale): array
    {
        $sale->loadMissing(['items', 'customer', 'discounts']);

        return [
            ...$sale->toSummaryArray(),
            'notes' => $sale->notes,
            'items' => $sale->items,
            'discounts' => $sale->discounts,
        ];
    }
}
