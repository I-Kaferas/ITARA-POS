<?php

namespace App\Services\Payments\Providers;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\RefundContext;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;

class BankTransferPaymentProvider extends AbstractPaymentProvider
{
    public function method(): SalePaymentMethod
    {
        return SalePaymentMethod::BankTransfer;
    }

    public function initiate(
        PaymentLineInput $line,
        PaymentContext $context,
        PaymentTransaction $transaction,
    ): PaymentLineResult {
        return $this->complete(
            transaction: $transaction,
            providerReference: $this->generateReference('VIR'),
            metadata: array_filter([
                'reference' => $line->metadata['reference'] ?? null,
                'account' => $line->metadata['account'] ?? null,
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
            providerReference: $this->generateReference('VIR-RFD'),
            metadata: array_filter([
                'original_transaction_id' => $originalTransaction->id,
                'original_provider_reference' => $originalTransaction->provider_reference,
                'reference' => $context->metadata['reference'] ?? $originalTransaction->metadata['reference'] ?? null,
                'sale_return_id' => $context->saleReturn->id,
            ]),
        );
    }
}
