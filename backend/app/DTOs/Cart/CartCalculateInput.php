<?php

namespace App\DTOs\Cart;

final readonly class CartCalculateInput
{
    /** @param  list<CartItemInput>  $items */
    public function __construct(
        public array $items,
        public ?CartDiscountInput $globalDiscount = null,
        public array $fees = [],
        public string $currency = 'FBU',
    ) {}

    /** @param  array<string, mixed>  $payload */
    public static function fromArray(array $payload): self
    {
        $items = [];
        foreach ($payload['items'] ?? [] as $index => $item) {
            $items[] = CartItemInput::fromArray($item, $index);
        }

        $fees = [];
        foreach ($payload['fees'] ?? [] as $fee) {
            $fees[] = CartFeeInput::fromArray($fee);
        }

        return new self(
            items: $items,
            globalDiscount: CartDiscountInput::fromArray($payload['global_discount'] ?? null),
            fees: $fees,
            currency: (string) ($payload['currency'] ?? 'FBU'),
        );
    }
}
