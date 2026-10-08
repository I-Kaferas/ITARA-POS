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
            currency: strtoupper((string) ($data['currency'] ?? 'FBU')),
            lines: $lines,
            customerId: $data['customer_id'] ?? null,
            cashRegisterId: $data['cash_register_id'] ?? null,
            idempotencyKey: $data['idempotency_key'] ?? null,
            cart: $data['cart'] ?? [],
            dueDate: $data['due_date'] ?? null,
        );
    }

    /** Paid total in sale currency (after FX conversion). */
    public function paidTotal(): int
    {
        return array_sum(array_map(fn (PaymentLineInput $line) => $line->appliedAmount(), $this->lines));
    }

    public function isMixed(): bool
    {
        return count($this->lines) > 1;
    }

    public function isMultiCurrency(): bool
    {
        foreach ($this->lines as $line) {
            if ($line->currency !== null && strtoupper($line->currency) !== $this->currency) {
                return true;
            }
        }

        return false;
    }

    /** @return list<string> */
    public function methods(): array
    {
        return array_map(fn (PaymentLineInput $line) => $line->method->value, $this->lines);
    }

    /** @param  list<PaymentLineInput>  $lines */
    public function withLines(array $lines): self
    {
        return new self(
            expectedTotal: $this->expectedTotal,
            currency: $this->currency,
            lines: $lines,
            customerId: $this->customerId,
            cashRegisterId: $this->cashRegisterId,
            idempotencyKey: $this->idempotencyKey,
            cart: $this->cart,
            dueDate: $this->dueDate,
        );
    }
}
