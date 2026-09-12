<?php

namespace App\DTOs\Payments;

final readonly class PaymentRequestInput
{
    /** @param  list<PaymentLineInput>  $lines */
    public function __construct(
        public int $expectedTotal,
        public string $currency,
        public array $lines,
        public ?string $customerId = null,
        public ?string $cashRegisterId = null,
        public ?string $idempotencyKey = null,
        public array $cart = [],
        public ?string $dueDate = null,
    ) {}

    /** @param  array<string, mixed>  $data */
    public static function fromArray(array $data): self
    {
        $lines = array_map(
            fn (array $line) => PaymentLineInput::fromArray($line),
            $data['payments'] ?? [],
        );

        return new self(
            expectedTotal: (int) ($data['expected_total'] ?? 0),
            currency: $data['currency'] ?? 'FBU',
            lines: $lines,
            customerId: $data['customer_id'] ?? null,
            cashRegisterId: $data['cash_register_id'] ?? null,
            idempotencyKey: $data['idempotency_key'] ?? null,
            cart: $data['cart'] ?? [],
            dueDate: $data['due_date'] ?? null,
        );
    }

    public function paidTotal(): int
    {
        return array_sum(array_map(fn (PaymentLineInput $line) => $line->amount, $this->lines));
    }

    public function isMixed(): bool
    {
        return count($this->lines) > 1;
    }

    /** @return list<string> */
    public function methods(): array
    {
        return array_map(fn (PaymentLineInput $line) => $line->method->value, $this->lines);
    }
}
