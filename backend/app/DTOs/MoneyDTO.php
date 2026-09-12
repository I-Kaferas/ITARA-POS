<?php

namespace App\DTOs;

use App\Support\Money\Money;

final readonly class MoneyDTO
{
    public function __construct(
        public int $amount,
        public string $currency = 'FBU',
    ) {}

    public static function fromMoney(Money $money): self
    {
        return new self($money->minor, $money->currency);
    }

    /** @return array{amount: int, currency: string} */
    public function toArray(): array
    {
        return [
            'amount' => $this->amount,
            'currency' => $this->currency,
        ];
    }
}
