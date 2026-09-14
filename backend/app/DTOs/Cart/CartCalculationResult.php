<?php

namespace App\DTOs\Cart;

final readonly class CartCalculationResult
{
    /**
     * @param  list<CalculatedCartLine>  $lines
     * @param  list<array{label: string, code: ?string, amount: int}>  $fees
     * @param  list<array{promotion_id: string, name: string, type: string, amount: int, line_id: ?string}>  $promotions
     */
    public function __construct(
        public int $subtotal,
        public int $lineDiscountsTotal,
        public int $promotionDiscountsTotal,
        public int $globalDiscountTotal,
        public int $discountTotal,
        public int $taxTotal,
        public int $feesTotal,
        public int $grandTotal,
        public array $lines,
        public array $fees,
        public string $currency,
        public array $promotions = [],
    ) {}

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return [
            'currency' => $this->currency,
            'subtotal' => $this->subtotal,
            'line_discounts_total' => $this->lineDiscountsTotal,
            'promotion_discounts_total' => $this->promotionDiscountsTotal,
            'global_discount_total' => $this->globalDiscountTotal,
            'discount_total' => $this->discountTotal,
            'tax_total' => $this->taxTotal,
            'fees_total' => $this->feesTotal,
            'grand_total' => $this->grandTotal,
            'lines' => array_map(fn (CalculatedCartLine $line) => $line->toArray(), $this->lines),
            'fees' => $this->fees,
            'promotions' => $this->promotions,
        ];
    }
}
