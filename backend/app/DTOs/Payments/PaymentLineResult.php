<?php

namespace App\DTOs\Payments;

use App\Enums\PaymentTransactionStatus;
use App\Models\PaymentTransaction;

final readonly class PaymentLineResult
{
    /** @param  array<string, mixed>  $metadata */
    public function __construct(
        public PaymentTransaction $transaction,
        public PaymentTransactionStatus $status,
        public ?string $providerReference = null,
        public array $metadata = [],
    ) {}

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return [
            'id' => $this->transaction->id,
            'transaction_number' => $this->transaction->transaction_number,
            'payment_method' => $this->transaction->payment_method->value,
            'amount' => $this->transaction->amount,
            'currency' => $this->transaction->currency,
            'status' => $this->status->value,
            'provider_reference' => $this->providerReference,
            'metadata' => $this->metadata,
        ];
    }
}
