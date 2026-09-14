<?php

namespace App\DTOs\Payments;

use App\Enums\SalePaymentMethod;

final readonly class PaymentLineInput
{
    /** @param  array<string, mixed>  $metadata */
    public function __construct(
        public SalePaymentMethod $method,
        public int $amount,
        public array $metadata = [],
    ) {}

    /** @param  array<string, mixed>  $data */
    public static function fromArray(array $data): self
    {
        return new self(
            method: SalePaymentMethod::from((string) $data['method']),
            amount: (int) ($data['amount'] ?? 0),
            metadata: is_array($data['metadata'] ?? null) ? $data['metadata'] : [],
        );
    }
}
