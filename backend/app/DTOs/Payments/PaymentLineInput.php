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
        public ?string $currency = null,
        public ?int $amountInSaleCurrency = null,
        public ?float $exchangeRate = null,
    ) {}

    /** @param  array<string, mixed>  $data */
    public static function fromArray(array $data): self
    {
        $currency = isset($data['currency']) ? strtoupper((string) $data['currency']) : null;

        return new self(
            method: SalePaymentMethod::from((string) $data['method']),
            amount: (int) ($data['amount'] ?? 0),
            metadata: is_array($data['metadata'] ?? null) ? $data['metadata'] : [],
            currency: $currency,
            amountInSaleCurrency: isset($data['amount_in_sale_currency'])
                ? (int) $data['amount_in_sale_currency']
                : null,
            exchangeRate: isset($data['exchange_rate']) ? (float) $data['exchange_rate'] : null,
        );
    }

    /** Amount applied against the sale total (sale currency). */
    public function appliedAmount(): int
    {
        return $this->amountInSaleCurrency ?? $this->amount;
    }

    public function paymentCurrency(string $saleCurrency): string
    {
        return $this->currency ?: $saleCurrency;
    }

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return [
            'method' => $this->method->value,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'amount_in_sale_currency' => $this->amountInSaleCurrency,
            'exchange_rate' => $this->exchangeRate,
            'metadata' => $this->metadata,
        ];
    }

    public function withFx(?string $currency, int $amountInSaleCurrency, float $exchangeRate): self
    {
        return new self(
            method: $this->method,
            amount: $this->amount,
            metadata: $this->metadata,
            currency: $currency,
            amountInSaleCurrency: $amountInSaleCurrency,
            exchangeRate: $exchangeRate,
        );
    }
}
