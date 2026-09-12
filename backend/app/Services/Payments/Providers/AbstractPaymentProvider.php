<?php

namespace App\Services\Payments\Providers;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\RefundContext;
use App\Enums\PaymentProviderType;
use App\Enums\PaymentTransactionStatus;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;
use App\Services\Payments\PaymentProviderInterface;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

abstract class AbstractPaymentProvider implements PaymentProviderInterface
{
    abstract public function method(): SalePaymentMethod;

    public function validate(PaymentLineInput $line, PaymentContext $context): void
    {
        if ($line->amount <= 0) {
            throw ValidationException::withMessages([
                'payments' => ["{$this->method()->value} amount must be greater than zero."],
            ]);
        }
    }

    public function refund(
        PaymentTransaction $originalTransaction,
        int $amount,
        RefundContext $context,
        PaymentTransaction $refundTransaction,
    ): PaymentLineResult {
        throw ValidationException::withMessages([
            'refund_method' => ["{$this->method()->value} refunds are not supported."],
        ]);
    }

    public function checkStatus(PaymentTransaction $transaction): PaymentTransactionStatus
    {
        return $transaction->status;
    }

    protected function providerType(): PaymentProviderType
    {
        return PaymentProviderType::forMethod($this->method());
    }

    protected function complete(
        PaymentTransaction $transaction,
        ?string $providerReference = null,
        array $metadata = [],
    ): PaymentLineResult {
        $now = now();

        $transaction->update([
            'status' => PaymentTransactionStatus::Completed,
            'provider_reference' => $providerReference,
            'metadata' => array_merge($transaction->metadata ?? [], $metadata),
            'completed_at' => $now,
        ]);

        return new PaymentLineResult(
            transaction: $transaction->fresh(),
            status: PaymentTransactionStatus::Completed,
            providerReference: $providerReference,
            metadata: $metadata,
        );
    }

    protected function completeRefund(
        PaymentTransaction $refundTransaction,
        ?string $providerReference = null,
        array $metadata = [],
    ): PaymentLineResult {
        $now = now();

        $refundTransaction->update([
            'status' => PaymentTransactionStatus::Completed,
            'provider_reference' => $providerReference,
            'metadata' => array_merge($refundTransaction->metadata ?? [], $metadata),
            'completed_at' => $now,
        ]);

        return new PaymentLineResult(
            transaction: $refundTransaction->fresh(),
            status: PaymentTransactionStatus::Completed,
            providerReference: $providerReference,
            metadata: $metadata,
        );
    }

    protected function generateReference(string $prefix): string
    {
        return strtoupper($prefix).'-'.Str::upper(Str::random(12));
    }
}
