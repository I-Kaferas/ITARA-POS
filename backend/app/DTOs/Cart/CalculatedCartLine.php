<?php

namespace App\DTOs\Cart;

final readonly class CalculatedCartLine
{
    public function __construct(
        public string $lineId,
        public int $unitPrice,
        public int $quantity,
        public int $lineSubtotal,
        public int $lineDiscount,
        public int $promotionDiscount,
        public int $lineNet,
        public int $globalDiscountShare,
        public int $taxableNet,
        public int $lineTax,
        public int $lineTotal,
        public string $taxRate,
        public bool $taxInclusive,
        public ?string $productId = null,
        public ?string $productVariantId = null,
        public ?string $sku = null,
        public ?string $name = null,
        public ?string $priceType = null,
        public ?string $saleUnitId = null,
        public ?int $volumeMl = null,
    ) {}

    public function stockQuantity(): int
    {
        if ($this->volumeMl !== null && $this->volumeMl > 0) {
            return $this->quantity * $this->volumeMl;
        }

        return $this->quantity;
    }

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return [
            'line_id' => $this->lineId,
            'product_id' => $this->productId,
            'product_variant_id' => $this->productVariantId,
            'sku' => $this->sku,
            'name' => $this->name,
            'price_type' => $this->priceType,
            'unit_price' => $this->unitPrice,
            'quantity' => $this->quantity,
            'line_subtotal' => $this->lineSubtotal,
            'promotion_discount' => $this->promotionDiscount,
            'line_discount' => $this->lineDiscount,
            'line_net' => $this->lineNet,
            'global_discount_share' => $this->globalDiscountShare,
            'taxable_net' => $this->taxableNet,
            'line_tax' => $this->lineTax,
            'line_total' => $this->lineTotal,
            'tax_rate' => $this->taxRate,
            'tax_inclusive' => $this->taxInclusive,
        ];
    }
}
