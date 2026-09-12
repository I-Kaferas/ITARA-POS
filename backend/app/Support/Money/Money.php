<?php

namespace App\Support\Money;

/**
 * Immutable monetary amount in minor units (e.g. cents). Never use float for money.
 */
final readonly class Money
{
    public function __construct(
        public int $minor,
        public string $currency = 'FBU',
    ) {}

    public function add(Money $other): self
    {
        $this->assertSameCurrency($other);

        return new self($this->minor + $other->minor, $this->currency);
    }

    public function subtract(Money $other): self
    {
        $this->assertSameCurrency($other);

        return new self($this->minor - $other->minor, $this->currency);
    }

    public function clampNonNegative(): self
    {
        return new self(max(0, $this->minor), $this->currency);
    }

    /** @return array{amount: int, currency: string} */
    public function toArray(): array
    {
        return [
            'amount' => $this->minor,
            'currency' => $this->currency,
        ];
    }

    private function assertSameCurrency(Money $other): void
    {
        if ($this->currency !== $other->currency) {
            throw new \InvalidArgumentException('Currency mismatch.');
        }
    }
}
