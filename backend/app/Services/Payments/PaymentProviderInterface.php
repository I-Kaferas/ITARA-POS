<?php

namespace App\Services\Payments;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\RefundContext;
use App\Enums\PaymentTransactionStatus;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;

interface PaymentProviderInterface
{
    public function method(): SalePaymentMethod;

    public function validate(PaymentLineInput $line, PaymentContext $context): void;

    public function initiate(
        PaymentLineInput $line,
        PaymentContext $context,
        PaymentTransaction $transaction,
    ): PaymentLineResult;

    public function refund(
        PaymentTransaction $originalTransaction,
        int $amount,
        RefundContext $context,
        PaymentTransaction $refundTransaction,
    ): PaymentLineResult;

    public function checkStatus(PaymentTransaction $transaction): PaymentTransactionStatus;
}
