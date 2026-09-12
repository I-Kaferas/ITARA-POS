<?php

namespace App\DTOs\Payments;

final readonly class PaymentValidationResult
{
    /** @param  list<array<string, mixed>>  $lines */
    public function __construct(
        public bool $valid,
        public int $expectedTotal,
        public int $paidTotal,
        public int $difference,
        public bool $isMixed,
        public array $lines,
        public array $errors = [],
        public string $currency = 'FBU',
    ) {}

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return [
            'valid' => $this->valid,
            'expected_total' => $this->expectedTotal,
            'paid_total' => $this->paidTotal,
            'difference' => $this->difference,
            'is_mixed' => $this->isMixed,
            'currency' => $this->currency,
            'lines' => $this->lines,
            'errors' => $this->errors,
        ];
    }
}
