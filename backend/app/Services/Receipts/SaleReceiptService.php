<?php

namespace App\Services\Receipts;

use App\Enums\SaleDocumentFormat;
use App\Models\Sale;
use App\Models\SaleReceipt;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class SaleReceiptService
{
    public function __construct(
        private readonly ReceiptPayloadService $payloadService,
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

        return SaleReceipt::query()->create([
            'tenant_id' => $sale->tenant_id,
            'sale_id' => $sale->id,
            'receipt_number' => $this->nextReceiptNumber($sale->tenant_id),
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

    private function nextReceiptNumber(string $tenantId): string
    {
        $prefix = config('receipts.receipt_prefix', 'REC');
        $count = SaleReceipt::query()->where('tenant_id', $tenantId)->count();

        return $prefix.'-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
