<?php

namespace App\Services\Receipts;

use App\Enums\NumberingDocumentType;
use App\Enums\SaleDocumentFormat;
use App\Models\Sale;
use App\Models\SaleReceipt;
use App\Models\User;
use App\Services\Numbering\ReferenceNumberGenerator;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class SaleReceiptService
{
    public function __construct(
        private readonly ReceiptPayloadService $payloadService,
        private readonly ReferenceNumberGenerator $numbering,
    ) {}

    /** @return array<string, mixed> */
    public function payload(Sale $sale, SaleDocumentFormat $format): array
    {
        $receipt = $sale->receipts()->latest('printed_at')->first();

        return $this->payloadService->build($sale, $format, $receipt);
    }

    public function issue(
        Sale $sale,
        SaleDocumentFormat $format,
        ?User $printedBy = null,
        ?string $deviceId = null,
        bool $isReprint = false,
    ): SaleReceipt {
        if ($sale->status->value !== 'completed') {
            throw ValidationException::withMessages([
                'sale' => ['Only completed sales can generate receipts.'],
            ]);
        }

        $existing = $sale->receipts()->first();

        if ($existing !== null && ! $isReprint) {
            return $existing;
        }

        if ($existing !== null && $isReprint) {
            $existing->increment('reprint_count');

            return $existing->fresh(['printedBy', 'device']);
        }

        $sale->loadMissing('store:id,branch_id');

        return SaleReceipt::query()->create([
            'tenant_id' => $sale->tenant_id,
            'sale_id' => $sale->id,
            'receipt_number' => $this->numbering->next(
                NumberingDocumentType::Receipt,
                (string) $sale->tenant_id,
                $sale->store?->branch_id,
            ),
            'format' => $format,
            'printed_by' => $printedBy?->id,
            'device_id' => $deviceId,
            'printed_at' => now(),
            'reprint_count' => 0,
        ]);
    }

    /** @return Collection<int, SaleReceipt> */
    public function listForSale(Sale $sale): Collection
    {
        return $sale->receipts()->with(['printedBy', 'device'])->get();
    }
}
