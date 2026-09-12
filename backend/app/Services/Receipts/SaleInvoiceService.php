<?php

namespace App\Services\Receipts;

use App\Enums\SaleDocumentFormat;
use App\Enums\SaleInvoiceStatus;
use App\Models\Sale;
use App\Models\SaleInvoice;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class SaleInvoiceService
{
    public function __construct(
        private readonly ReceiptPayloadService $payloadService,
    ) {}

    /** @return array<string, mixed> */
    public function payload(Sale $sale, SaleDocumentFormat $format): array
    {
        $invoice = $sale->invoices()
            ->where('status', SaleInvoiceStatus::Issued)
            ->latest('issued_at')
            ->first();

        return $this->payloadService->build($sale, $format, invoice: $invoice);
    }

    public function issue(
        Sale $sale,
        SaleDocumentFormat $format,
        ?User $issuedBy = null,
    ): SaleInvoice {
        if ($sale->status->value !== 'completed') {
            throw ValidationException::withMessages([
                'sale' => ['Only completed sales can generate invoices.'],
            ]);
        }

        $existing = $sale->invoices()
            ->where('status', SaleInvoiceStatus::Issued)
            ->first();

        if ($existing !== null) {
            return $existing;
        }

        return SaleInvoice::query()->create([
            'tenant_id' => $sale->tenant_id,
            'sale_id' => $sale->id,
            'invoice_number' => $this->nextInvoiceNumber($sale->tenant_id),
            'status' => SaleInvoiceStatus::Issued,
            'format' => $format,
            'issued_by' => $issuedBy?->id,
            'issued_at' => now(),
        ]);
    }

    public function cancel(SaleInvoice $invoice, ?User $cancelledBy = null): SaleInvoice
    {
        if ($invoice->status === SaleInvoiceStatus::Cancelled) {
            throw ValidationException::withMessages([
                'invoice' => ['Invoice is already cancelled.'],
            ]);
        }

        $invoice->update([
            'status' => SaleInvoiceStatus::Cancelled,
            'cancelled_by' => $cancelledBy?->id,
            'cancelled_at' => now(),
        ]);

        return $invoice->fresh(['issuedBy', 'cancelledBy']);
    }

    /** @return Collection<int, SaleInvoice> */
    public function listForSale(Sale $sale): Collection
    {
        return $sale->invoices()->with(['issuedBy', 'cancelledBy'])->get();
    }

    private function nextInvoiceNumber(string $tenantId): string
    {
        $prefix = config('receipts.invoice_prefix', 'INV');
        $count = SaleInvoice::query()->where('tenant_id', $tenantId)->count();

        return $prefix.'-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
