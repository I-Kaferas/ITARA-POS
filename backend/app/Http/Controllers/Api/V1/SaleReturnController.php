<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SaleReturnRefundMethod;
use App\Http\Controllers\Controller;
use App\Models\Sale;
use App\Models\SaleReturn;
use App\Models\Store;
use App\Services\Sales\SaleReturnEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SaleReturnController extends Controller
{
    public function __construct(
        private readonly SaleReturnEngine $saleReturnEngine,
    ) {}

    public function reasons(): JsonResponse
    {
        return response()->json([
            'data' => collect(config('returns.reasons', []))
                ->map(fn (string $label, string $value) => [
                    'value' => $value,
                    'label' => $label,
                ])
                ->values(),
        ]);
    }

    public function index(Sale $sale): JsonResponse
    {
        $returns = $this->saleReturnEngine->listForSale($sale);

        return response()->json([
            'data' => $returns->map(fn (SaleReturn $return) => $return->toSummaryArray())->values(),
        ]);
    }

    public function indexForStore(Request $request, Store $store): JsonResponse
    {
        $limit = min(100, max(1, (int) $request->query('limit', 50)));
        $returns = $this->saleReturnEngine->listForStore($store, $limit);

        return response()->json([
            'data' => $returns->map(fn (SaleReturn $return) => [
                ...$return->toSummaryArray(),
                'sale' => $return->sale?->only(['id', 'reference', 'total']),
                'customer' => $return->customer?->only(['id', 'name']),
            ])->values(),
        ]);
    }

    public function store(Request $request, Sale $sale): JsonResponse
    {
        $request->merge([
            'refund_method' => $this->normalizeRefundMethod($sale, $request->input('refund_method')),
        ]);

        $data = $this->validatePayload($request);

        $data['idempotency_key'] = $data['idempotency_key']
            ?? $request->header('Idempotency-Key');

        $result = $this->saleReturnEngine->create($sale, $data, $request->user());

        return response()->json(['data' => $result->toArray()], 201);
    }

    public function show(SaleReturn $saleReturn): JsonResponse
    {
        $saleReturn = $this->saleReturnEngine->find($saleReturn->id);

        return response()->json([
            'data' => [
                ...$saleReturn->toSummaryArray(),
                'items' => $saleReturn->items,
                'refunds' => $saleReturn->refunds->map(fn ($refund) => $refund->toSummaryArray())->values(),
                'sale' => $saleReturn->sale?->only(['id', 'reference', 'total']),
                'customer' => $saleReturn->customer?->only(['id', 'name']),
                'processed_by' => $saleReturn->processedBy?->only(['id', 'name']),
                'approved_by' => $saleReturn->approvedBy?->only(['id', 'name']),
            ],
        ]);
    }

    private function normalizeRefundMethod(Sale $sale, mixed $method): string
    {
        $method = is_string($method) && $method !== '' ? $method : 'cash';

        if ($method === 'store_credit') {
            return SaleReturnRefundMethod::Credit->value;
        }

        if ($method !== 'original') {
            return $method;
        }

        $sale->loadMissing('payments');
        $payment = $sale->payments->first(fn ($row) => ! in_array($row->payment_method, ['credit', 'wallet'], true))
            ?? $sale->payments->first();
        $code = (string) ($payment?->payment_method ?? 'cash');

        return match ($code) {
            'card' => SaleReturnRefundMethod::Card->value,
            'mobile_money' => SaleReturnRefundMethod::MobileMoney->value,
            'wallet' => SaleReturnRefundMethod::Wallet->value,
            'bank_transfer' => SaleReturnRefundMethod::BankTransfer->value,
            'credit' => SaleReturnRefundMethod::Credit->value,
            default => SaleReturnRefundMethod::Cash->value,
        };
    }

    /** @return array<string, mixed> */
    private function validatePayload(Request $request): array
    {
        return $request->validate([
            'reason' => ['required', 'string', 'max:100'],
            'refund_method' => ['nullable', Rule::in(SaleReturnRefundMethod::values())],
            'cash_register_id' => ['nullable', 'uuid', 'exists:cash_registers,id'],
            'refund_metadata' => ['nullable', 'array'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'idempotency_key' => ['nullable', 'string', 'max:100'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.sale_item_id' => ['required', 'uuid', 'exists:sale_items,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.batch_id' => ['nullable', 'uuid', 'exists:batches,id'],
        ]);
    }
}
