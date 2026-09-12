<?php

namespace App\Services\Payments\Providers;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\Enums\CustomerTransactionType;
use App\Enums\SalePaymentMethod;
use App\Models\PaymentTransaction;
use App\Services\Customer\CustomerLedgerService;
use Illuminate\Validation\ValidationException;

class CreditPaymentProvider extends AbstractPaymentProvider
{
    public function __construct(
        private readonly CustomerLedgerService $ledger,
    ) {}

    public function method(): SalePaymentMethod
    {
        return SalePaymentMethod::Credit;
    }

    public function validate(PaymentLineInput $line, PaymentContext $context): void
    {
        parent::validate($line, $context);

        if ($context->customer === null) {
            throw ValidationException::withMessages([
                'customer_id' => ['Customer is required for credit payments.'],
            ]);
        }

        $available = $this->ledger->availableCredit($context->customer);

        if ($available === null) {
            throw ValidationException::withMessages([
                'customer_id' => ['Customer has no credit limit configured.'],
            ]);
        }

        if ($line->amount > $available) {
            throw ValidationException::withMessages([
                'payments' => ["Insufficient available credit. Available: {$available}."],
            ]);
        }
    }

    public function initiate(
        PaymentLineInput $line,
        PaymentContext $context,
        PaymentTransaction $transaction,
    ): PaymentLineResult {
        $customerTransaction = $this->ledger->recordReceivable($context->customer, [
            'transaction_type' => CustomerTransactionType::Sale,
            'amount' => $line->amount,
            'reference' => $context->sale?->reference ?? $context->transactionNumber,
            'description' => $context->sale
                ? "Sale {$context->sale->reference}"
                : "POS credit payment {$context->transactionNumber}",
            'sale_id' => $context->sale?->id,
            'due_date' => $context->dueDate,
            'recorded_by' => $context->processedBy?->id,
            'earn_loyalty' => $context->sale !== null,
        ]);

        return $this->complete(
            transaction: $transaction,
            providerReference: $this->generateReference('CRD-ACC'),
            metadata: [
                'customer_id' => $context->customer?->id,
                'customer_transaction_id' => $customerTransaction->id,
            ],
        );
    }
}
