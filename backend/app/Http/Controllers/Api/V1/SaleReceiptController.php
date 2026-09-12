<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SaleDocumentFormat;
use App\Http\Controllers\Controller;
use App\Models\Sale;
use App\Services\Receipts\ReceiptPayloadService;
use App\Services\Receipts\SaleReceiptService;
use App\Services\Sales\SaleEngine;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SaleReceiptController extends Controller
{
    public function __construct(
        private readonly SaleEngine $saleEngine,
        private readonly SaleReceiptService $receiptService,
        private readonly ReceiptPayloadService $payloadService,
        private readonly TenantContext $tenantContext,
    ) {}

    public function show(Request $request, Sale $sale): JsonResponse
    {
        $this->ensureTenantSale($sale);

        $format = $this->resolveFormat($request, SaleDocumentFormat::Thermal80);
        $sale = $this->saleEngine->find($sale->id);

        return response()->json([
            'data' => $this->receiptService->payload($sale, $format),
        ]);
    }

    public function store(Request $request, Sale $sale): JsonResponse
    {
        $this->ensureTenantSale($sale);

        $data = $request->validate([
            'format' => ['nullable', Rule::in(SaleDocumentFormat::values())],
            'device_id' => ['nullable', 'uuid', 'exists:devices,id'],
            'reprint' => ['nullable', 'boolean'],
        ]);

        $format = isset($data['format'])
            ? SaleDocumentFormat::from($data['format'])
            : SaleDocumentFormat::Thermal80;

        $sale = $this->saleEngine->find($sale->id);

        $receipt = $this->receiptService->issue(
            sale: $sale,
            format: $format,
            printedBy: $request->user(),
            deviceId: $data['device_id'] ?? null,
            isReprint: (bool) ($data['reprint'] ?? false),
        );

        return response()->json([
            'data' => [
                'receipt' => $receipt->toSummaryArray(),
                'payload' => $this->payloadService->build($sale, $format, $receipt),
            ],
        ], 201);
    }

    public function index(Sale $sale): JsonResponse
    {
        $this->ensureTenantSale($sale);

        $receipts = $this->receiptService->listForSale($sale);

        return response()->json([
            'data' => $receipts->map(fn ($receipt) => $receipt->toSummaryArray())->values(),
        ]);
    }

    public function formats(): JsonResponse
    {
        return response()->json([
            'data' => collect(SaleDocumentFormat::cases())
                ->map(fn (SaleDocumentFormat $format) => [
                    'value' => $format->value,
                    'label' => $format->label(),
                    'is_thermal' => $format->isThermal(),
                    'paper_width_mm' => $format->paperWidthMm(),
                ])
                ->values(),
        ]);
    }

    private function resolveFormat(Request $request, SaleDocumentFormat $default): SaleDocumentFormat
    {
        $value = $request->query('format');

        if ($value === null) {
            return $default;
        }

        return SaleDocumentFormat::from($value);
    }

    private function ensureTenantSale(Sale $sale): void
    {
        if ($sale->tenant_id !== $this->tenantContext->requireId()) {
            abort(404);
        }
    }
}
