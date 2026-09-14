<?php

namespace App\DTOs\Cart;

final readonly class CartFeeInput
{
    public function __construct(
        public string $label,
        public int $amount,
        public ?string $code = null,
    ) {}

    /** @param  array<string, mixed>  $payload */
    public static function fromArray(array $payload): self
    {
        return new self(
            label: (string) ($payload['label'] ?? 'Fee'),
            amount: (int) ($payload['amount'] ?? 0),
            code: isset($payload['code']) ? (string) $payload['code'] : null,
        );
    }
}
