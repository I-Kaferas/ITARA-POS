<?php

namespace App\Services\Payments\Providers;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\RefundContext;
use App\Enums\CashMovementType;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;
use App\Services\Registers\CashRegisterSessionService;

class CashPaymentProvider extends AbstractPaymentProvider
{
    public function __construct(
        private readonly CashRegisterSessionService $cashRegisterSessions,
    ) {}

    public function method(): SalePaymentMethod
    {
        return SalePaymentMethod::Cash;
    }

    public function initiate(
        PaymentLineInput $line,
        PaymentContext $context,
        PaymentTransaction $transaction,
    ): PaymentLineResult {
        $metadata = $line->metadata;
        $tendered = isset($metadata['tendered']) ? (int) $metadata['tendered'] : $line->amount;
        $change = max(0, $tendered - $line->amount);

        if ($context->cashRegister !== null && $context->processedBy !== null) {
            $session = $context->cashRegister->openSession()->first();

            if ($session !== null) {
                $this->cashRegisterSessions->recordMovement(
                    register: $context->cashRegister,
                    session: $session,
                    type: CashMovementType::Sale,
                    amount: $line->amount,
                    user: $context->processedBy,
                    description: "Payment {$context->transactionNumber}",
                    reference: $context->transactionNumber,
                    referenceType: PaymentTransaction::class,
                    referenceId: $transaction->id,
                );
            }
        }

        return $this->complete(
            transaction: $transaction,
            providerReference: $this->generateReference('CSH'),
            metadata: array_filter([
                'tendered' => $tendered !== $line->amount ? $tendered : null,
                'change' => $change > 0 ? $change : null,
            ]),
        );
    }

    public function refund(
        PaymentTransaction $originalTransaction,
        int $amount,
        RefundContext $context,
        PaymentTransaction $refundTransaction,
    ): PaymentLineResult {
        if ($context->cashRegister !== null) {
            $session = $context->cashRegister->openSession()->firstOrFail();

            $this->cashRegisterSessions->recordMovement(
                register: $context->cashRegister,
                session: $session,
                type: CashMovementType::Refund,
                amount: $amount,
                user: $context->processedBy,
                description: "Refund {$context->refundNumber}",
                reference: $context->refundNumber,
                referenceType: PaymentTransaction::class,
                referenceId: $refundTransaction->id,
            );
        }

        return $this->completeRefund(
            refundTransaction: $refundTransaction,
            providerReference: $this->generateReference('CSH-RFD'),
            metadata: [
                'original_transaction_id' => $originalTransaction->id,
                'sale_return_id' => $context->saleReturn->id,
            ],
        );
    }
}
