<?php

namespace App\Services\Payments\Providers;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\RefundContext;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;
use App\Services\Customer\CustomerLedgerService;
use Illuminate\Validation\ValidationException;

class WalletPaymentProvider extends AbstractPaymentProvider
{
    public function __construct(
        private readonly CustomerLedgerService $ledger,
    ) {}

    public function method(): SalePaymentMethod
    {
        return SalePaymentMethod::Wallet;
    }

    public function validate(PaymentLineInput $line, PaymentContext $context): void
    {
        parent::validate($line, $context);

        if ($context->customer === null) {
            throw ValidationException::withMessages([
                'customer_id' => ['Customer is required for wallet payments.'],
            ]);
        }

        $available = $this->ledger->credit($context->customer);

        if ($line->amount > $available) {
            throw ValidationException::withMessages([
                'payments' => ["Insufficient wallet balance. Available: {$available}."],
            ]);
        }
    }

    public function initiate(
        PaymentLineInput $line,
        PaymentContext $context,
        PaymentTransaction $transaction,
    ): PaymentLineResult {
        return $this->complete(
            transaction: $transaction,
            providerReference: $this->generateReference('WLT'),
            metadata: [
                'customer_id' => $context->customer?->id,
                'wallet_balance_before' => $context->customer
                    ? $this->ledger->credit($context->customer)
                    : 0,
            ],
        );
    }

    public function refund(
        PaymentTransaction $originalTransaction,
        int $amount,
        RefundContext $context,
        PaymentTransaction $refundTransaction,
    ): PaymentLineResult {
        if ($context->customer === null) {
            throw ValidationException::withMessages([
                'customer_id' => ['Customer is required for wallet refunds.'],
            ]);
        }

        $balanceBefore = $this->ledger->credit($context->customer);

        $customerTransaction = $this->ledger->recordWalletRefund(
            customer: $context->customer,
            amount: $amount,
            sale: $context->sale,
            reference: $context->refundNumber,
            description: "Wallet refund {$context->refundNumber} for return {$context->saleReturn->return_number}",
            recordedBy: $context->processedBy->id,
        );

        return $this->completeRefund(
            refundTransaction: $refundTransaction,
            providerReference: $this->generateReference('WLT-RFD'),
            metadata: [
                'original_transaction_id' => $originalTransaction->id,
                'customer_transaction_id' => $customerTransaction->id,
                'wallet_balance_before' => $balanceBefore,
                'sale_return_id' => $context->saleReturn->id,
            ],
        );
    }
}
