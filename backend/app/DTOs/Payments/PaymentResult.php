<?php

namespace App\DTOs\Payments;

final readonly class PaymentResult
{
    /** @param  list<PaymentLineResult>  $lines */
    public function __construct(
        public string $transactionNumber,
        public int $expectedTotal,
        public int $paidTotal,
        public bool $isMixed,
        public string $currency,
        public array $lines,
        public ?string $idempotencyKey = null,
    ) {}
}
