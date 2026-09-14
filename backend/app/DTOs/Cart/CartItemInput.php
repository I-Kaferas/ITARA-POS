<?php

namespace App\DTOs\Cart;

final readonly class CartItemInput
{
    public function __construct(
        public string $lineId,
        public int $unitPrice,
        public int $quantity,
        public string $taxRate,
        public bool $taxInclusive,
        public ?CartDiscountInput $lineDiscount = null,
        public ?string $productId = null,
        public ?string $productVariantId = null,
        public ?string $sku = null,
        public ?string $name = null,
        public ?string $priceType = null,
        public ?string $saleUnitId = null,
        public ?int $volumeMl = null,
    ) {}

    /** @param  array<string, mixed>  $payload */
    public static function fromArray(array $payload, int $index): self
    {
        return new self(
            lineId: (string) ($payload['line_id'] ?? "line-{$index}"),
            unitPrice: (int) $payload['unit_price'],
            quantity: max(1, (int) ($payload['quantity'] ?? 1)),
            taxRate: number_format((float) ($payload['tax_rate'] ?? 0), 4, '.', ''),
            taxInclusive: (bool) ($payload['tax_inclusive'] ?? false),
            lineDiscount: CartDiscountInput::fromArray($payload['line_discount'] ?? null),
            productId: isset($payload['product_id']) ? (string) $payload['product_id'] : null,
            productVariantId: isset($payload['product_variant_id']) ? (string) $payload['product_variant_id'] : null,
            sku: isset($payload['sku']) ? (string) $payload['sku'] : null,
            name: isset($payload['name']) ? (string) $payload['name'] : null,
            priceType: isset($payload['price_type']) ? (string) $payload['price_type'] : null,
            saleUnitId: isset($payload['sale_unit_id']) ? (string) $payload['sale_unit_id'] : null,
            volumeMl: isset($payload['volume_ml']) ? (int) $payload['volume_ml'] : null,
        );
    }
}
