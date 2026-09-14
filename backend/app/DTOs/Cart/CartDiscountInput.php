<?php

namespace App\DTOs\Cart;

use App\Enums\CartDiscountType;

final readonly class CartDiscountInput
{
    public function __construct(
        public CartDiscountType $type,
        public int|float|string $value,
    ) {}

    /** @param  array<string, mixed>|null  $payload */
    public static function fromArray(?array $payload): ?self
    {
        if ($payload === null || ! isset($payload['type'], $payload['value'])) {
            return null;
        }

        $type = CartDiscountType::tryFrom((string) $payload['type']);
        if ($type === null) {
            return null;
        }

        return new self($type, $payload['value']);
    }
}
