<?php

namespace App\Services\Payments\Providers;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\RefundContext;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;

class MobileMoneyPaymentProvider extends AbstractPaymentProvider
{
    public function method(): SalePaymentMethod
    {
        return SalePaymentMethod::MobileMoney;
    }

    public function initiate(
        PaymentLineInput $line,
        PaymentContext $context,
        PaymentTransaction $transaction,
    ): PaymentLineResult {
        return $this->complete(
            transaction: $transaction,
            providerReference: $this->generateReference('MMO'),
            metadata: array_filter([
                'phone' => $line->metadata['phone'] ?? null,
                'operator' => $line->metadata['operator'] ?? null,
            ]),
        );
    }

    public function refund(
        PaymentTransaction $originalTransaction,
        int $amount,
        RefundContext $context,
        PaymentTransaction $refundTransaction,
    ): PaymentLineResult {
        return $this->completeRefund(
            refundTransaction: $refundTransaction,
            providerReference: $this->generateReference('MMO-RFD'),
            metadata: array_filter([
                'original_transaction_id' => $originalTransaction->id,
                'original_provider_reference' => $originalTransaction->provider_reference,
                'phone' => $context->metadata['phone'] ?? $originalTransaction->metadata['phone'] ?? null,
                'operator' => $context->metadata['operator'] ?? $originalTransaction->metadata['operator'] ?? null,
                'sale_return_id' => $context->saleReturn->id,
            ]),
        );
    }
}
