<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SaleDocumentFormat;
use App\Http\Controllers\Controller;
use App\Models\Sale;
use App\Models\SaleInvoice;
use App\Services\Receipts\ReceiptPayloadService;
use App\Services\Receipts\SaleInvoiceService;
use App\Services\Sales\SaleEngine;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SaleInvoiceController extends Controller
{
    public function __construct(
        private readonly SaleEngine $saleEngine,
        private readonly SaleInvoiceService $invoiceService,
        private readonly ReceiptPayloadService $payloadService,
        private readonly TenantContext $tenantContext,
    ) {}

    public function show(Request $request, Sale $sale): JsonResponse
    {
        $this->ensureTenantSale($sale);

        $format = $this->resolveFormat($request, SaleDocumentFormat::A4);
        $sale = $this->saleEngine->find($sale->id);

        return response()->json([
            'data' => $this->invoiceService->payload($sale, $format),
        ]);
    }

    public function store(Request $request, Sale $sale): JsonResponse
    {
        $this->ensureTenantSale($sale);

        $data = $request->validate([
            'format' => ['nullable', Rule::in([SaleDocumentFormat::A4->value, SaleDocumentFormat::Pdf->value])],
        ]);

        $format = isset($data['format'])
            ? SaleDocumentFormat::from($data['format'])
            : SaleDocumentFormat::A4;

        $sale = $this->saleEngine->find($sale->id);

        $invoice = $this->invoiceService->issue(
            sale: $sale,
            format: $format,
            issuedBy: $request->user(),
        );

        return response()->json([
            'data' => [
                'invoice' => $invoice->toSummaryArray(),
                'payload' => $this->payloadService->build($sale, $format, invoice: $invoice),
            ],
        ], 201);
    }

    public function index(Sale $sale): JsonResponse
    {
        $this->ensureTenantSale($sale);

        $invoices = $this->invoiceService->listForSale($sale);

        return response()->json([
            'data' => $invoices->map(fn ($invoice) => $invoice->toSummaryArray())->values(),
        ]);
    }

    public function cancel(SaleInvoice $invoice): JsonResponse
    {
        $this->ensureTenantInvoice($invoice);

        $cancelled = $this->invoiceService->cancel($invoice, request()->user());

        return response()->json([
            'data' => $cancelled->toSummaryArray(),
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

    private function ensureTenantInvoice(SaleInvoice $invoice): void
    {
        if ($invoice->tenant_id !== $this->tenantContext->requireId()) {
            abort(404);
        }
    }
}
