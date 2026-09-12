<?php

namespace App\Services\Payments\Providers;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\RefundContext;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;

class CardPaymentProvider extends AbstractPaymentProvider
{
    public function method(): SalePaymentMethod
    {
        return SalePaymentMethod::Card;
    }

    public function initiate(
        PaymentLineInput $line,
        PaymentContext $context,
        PaymentTransaction $transaction,
    ): PaymentLineResult {
        return $this->complete(
            transaction: $transaction,
            providerReference: $this->generateReference('CRD'),
            metadata: array_filter([
                'last_four' => $line->metadata['last_four'] ?? null,
                'card_brand' => $line->metadata['card_brand'] ?? null,
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
            providerReference: $this->generateReference('CRD-RFD'),
            metadata: array_filter([
                'original_transaction_id' => $originalTransaction->id,
                'original_provider_reference' => $originalTransaction->provider_reference,
                'last_four' => $context->metadata['last_four'] ?? $originalTransaction->metadata['last_four'] ?? null,
                'card_brand' => $context->metadata['card_brand'] ?? $originalTransaction->metadata['card_brand'] ?? null,
                'sale_return_id' => $context->saleReturn->id,
            ]),
        );
    }
}
