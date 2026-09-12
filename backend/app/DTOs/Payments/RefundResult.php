<?php

namespace App\DTOs\Payments;

use App\Models\SaleRefund;

final readonly class RefundResult
{
    public function __construct(
        public SaleRefund $saleRefund,
    ) {}

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return $this->saleRefund->toSummaryArray();
    }
}
