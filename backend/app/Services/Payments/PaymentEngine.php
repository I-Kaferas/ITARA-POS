<?php

namespace App\Services\Payments;

use App\DTOs\Payments\PaymentContext;
use App\DTOs\Payments\PaymentLineInput;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\PaymentRequestInput;
use App\DTOs\Payments\PaymentResult;
use App\DTOs\Payments\PaymentValidationResult;
use App\Enums\PaymentProviderType;
use App\Enums\PaymentTransactionStatus;
use App\Enums\PaymentTransactionType;
use App\Enums\SalePaymentMethod;
use App\Events\PaymentProcessed;
use App\Models\CashRegister;
use App\Models\Customer;
use App\Models\PaymentTransaction;
use App\Models\Sale;
use App\Models\Store;
use App\Models\User;
use App\Services\Sales\CartEngine;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PaymentEngine
{
    public function __construct(
        private readonly CartEngine $cartEngine,
        private readonly PaymentProviderRegistry $registry,
        private readonly CompanyPaymentMethodService $companyPaymentMethods,
    ) {}

    /** @param  array<string, mixed>  $payload */
    public function validate(Store $store, array $payload): PaymentValidationResult
    {
        $input = $this->buildInput($store, $payload);
        $errors = $this->collectValidationErrors($store, $input);

        return new PaymentValidationResult(
            valid: $errors === [],
            expectedTotal: $input->expectedTotal,
            paidTotal: $input->paidTotal(),
            difference: $input->paidTotal() - $input->expectedTotal,
            isMixed: $input->isMixed(),
            lines: array_map(fn ($line) => $line->toArray(), $input->lines),
            errors: $errors,
            currency: $input->currency,
        );
    }

    /** @param  array<string, mixed>  $payload */
    public function process(Store $store, array $payload, User $user): PaymentResult
    {
        $input = $this->buildInput($store, $payload);

        if ($input->idempotencyKey !== null) {
            $existing = $this->findByIdempotencyKey($store->tenant_id, $input->idempotencyKey);

            if ($existing !== null) {
                return $existing;
            }
        }

        $errors = $this->collectValidationErrors($store, $input);

        if ($errors !== []) {
            throw ValidationException::withMessages(['payments' => $errors]);
        }

        $customer = $input->customerId
            ? Customer::query()->findOrFail($input->customerId)
            : null;

        $cashRegister = CashRegister::findForStore($store, $input->cashRegisterId);

        $transactionNumber = $this->nextTransactionNumber($store->tenant_id);

        $context = new PaymentContext(
            store: $store,
            expectedTotal: $input->expectedTotal,
            currency: $input->currency,
            customer: $customer,
            processedBy: $user,
            cashRegister: $cashRegister,
            transactionNumber: $transactionNumber,
            idempotencyKey: $input->idempotencyKey,
            dueDate: $input->dueDate,
        );

        return DB::transaction(function () use ($store, $input, $context, $user, $customer, $cashRegister): PaymentResult {
            return $this->executePaymentLines($store, $input, $context);
        });
    }

    /**
     * Process payments as part of a sale transaction (no outer DB::transaction).
     */
    public function processForSale(Store $store, array $payload, User $user, Sale $sale): PaymentResult
    {
        $input = $this->buildInput($store, $payload);
        $errors = $this->collectValidationErrors($store, $input);

        if ($errors !== []) {
            throw ValidationException::withMessages(['payments' => $errors]);
        }

        $customer = $input->customerId
            ? Customer::query()->findOrFail($input->customerId)
            : null;

        $cashRegister = CashRegister::findForStore($store, $input->cashRegisterId);

        $transactionNumber = $this->nextTransactionNumber($store->tenant_id);

        $context = new PaymentContext(
            store: $store,
            expectedTotal: $input->expectedTotal,
            currency: $input->currency,
            customer: $customer,
            processedBy: $user,
            cashRegister: $cashRegister,
            transactionNumber: $transactionNumber,
            idempotencyKey: null,
            sale: $sale,
            dueDate: $input->dueDate,
        );

        return $this->executePaymentLines($store, $input, $context);
    }

    /** @return list<PaymentLineResult> */
    private function executePaymentLines(Store $store, PaymentRequestInput $input, PaymentContext $context): PaymentResult
    {
        $lineResults = [];
        $isFirst = true;

        foreach ($input->lines as $line) {
            $provider = $this->registry->resolve($line->method);

            $transaction = PaymentTransaction::query()->create([
                'tenant_id' => $store->tenant_id,
                'store_id' => $store->id,
                'sale_id' => $context->sale?->id,
                'transaction_number' => $context->transactionNumber,
                'transaction_type' => PaymentTransactionType::Payment,
                'payment_method' => $line->method,
                'amount' => $line->amount,
                'currency' => $input->currency,
                'status' => PaymentTransactionStatus::Pending,
                'provider_type' => PaymentProviderType::forMethod($line->method),
                'idempotency_key' => $isFirst ? $input->idempotencyKey : null,
                'customer_id' => $context->customer?->id,
                'cash_register_id' => $context->cashRegister?->id,
                'processed_by' => $context->processedBy?->id,
                'metadata' => $line->metadata,
            ]);

            $lineResults[] = $provider->initiate($line, $context, $transaction);
            $isFirst = false;
        }

        $result = new PaymentResult(
            transactionNumber: $context->transactionNumber,
            expectedTotal: $input->expectedTotal,
            paidTotal: $input->paidTotal(),
            isMixed: $input->isMixed(),
            currency: $input->currency,
            lines: $lineResults,
            idempotencyKey: $input->idempotencyKey,
        );

        if ($context->sale === null) {
            event(new PaymentProcessed($result, $store));
        }

        return $result;
    }

    public function findTransaction(string $transactionId): PaymentTransaction
    {
        return PaymentTransaction::query()->findOrFail($transactionId);
    }

    public function status(PaymentTransaction $transaction): PaymentTransactionStatus
    {
        $provider = $this->registry->resolve($transaction->payment_method);

        return $provider->checkStatus($transaction);
    }

    /** @param  array<string, mixed>  $payload */
    private function buildInput(Store $store, array $payload): PaymentRequestInput
    {
        if (($payload['payments'] ?? []) === []) {
            throw ValidationException::withMessages([
                'payments' => ['At least one payment line is required.'],
            ]);
        }

        $cartPayload = $payload['cart'] ?? $payload;
        unset($cartPayload['payments'], $cartPayload['expected_total'], $cartPayload['customer_id'], $cartPayload['cash_register_id'], $cartPayload['idempotency_key']);

        $cartResult = $this->cartEngine->calculateForStore($store, $cartPayload);

        $input = PaymentRequestInput::fromArray([
            ...$payload,
            'expected_total' => $cartResult->grandTotal,
            'currency' => $cartResult->currency,
            'cart' => $cartPayload,
        ]);

        return $this->normalizeCreditBalance($input);
    }

    private function normalizeCreditBalance(PaymentRequestInput $input): PaymentRequestInput
    {
        $difference = $input->expectedTotal - $input->paidTotal();

        if ($difference <= 0 || $input->customerId === null) {
            return $input;
        }

        $lines = $input->lines;
        $lines[] = new PaymentLineInput(
            method: SalePaymentMethod::Credit,
            amount: $difference,
        );

        return new PaymentRequestInput(
            expectedTotal: $input->expectedTotal,
            currency: $input->currency,
            lines: $lines,
            customerId: $input->customerId,
            cashRegisterId: $input->cashRegisterId,
            idempotencyKey: $input->idempotencyKey,
            cart: $input->cart,
            dueDate: $input->dueDate,
        );
    }

    /** @return list<string> */
    private function collectValidationErrors(Store $store, PaymentRequestInput $input): array
    {
        $errors = [];

        if ($input->lines === []) {
            return ['At least one payment line is required.'];
        }

        if ($input->paidTotal() !== $input->expectedTotal) {
            $errors[] = sprintf(
                'Payment total (%d) does not match expected total (%d).',
                $input->paidTotal(),
                $input->expectedTotal,
            );
        }

        $customer = $input->customerId
            ? Customer::query()->find($input->customerId)
            : null;

        $cashRegister = $input->cashRegisterId
            ? CashRegister::query()->where('store_id', $store->id)->find($input->cashRegisterId)
            : null;

        $context = new PaymentContext(
            store: $store,
            expectedTotal: $input->expectedTotal,
            currency: $input->currency,
            customer: $customer,
            processedBy: null,
            cashRegister: $cashRegister,
            transactionNumber: 'VALIDATE',
        );

        $enabledCodes = $this->companyPaymentMethods->enabledCodesForStore($store);

        foreach ($input->lines as $line) {
            if ($enabledCodes !== [] && ! in_array($line->method->value, $enabledCodes, true)) {
                $errors[] = "Payment method {$line->method->value} is not enabled for this company.";

                continue;
            }

            if ($line->method->requiresCustomer() && $customer === null) {
                $errors[] = "Customer is required for {$line->method->value} payments.";

                continue;
            }

            try {
                $this->registry->resolve($line->method)->validate($line, $context);
            } catch (ValidationException $e) {
                foreach ($e->errors() as $fieldErrors) {
                    foreach ($fieldErrors as $message) {
                        $errors[] = $message;
                    }
                }
            }
        }

        return array_values(array_unique($errors));
    }

    private function findByIdempotencyKey(string $tenantId, string $key): ?PaymentResult
    {
        $first = PaymentTransaction::query()
            ->withoutGlobalScopes()
            ->where('tenant_id', $tenantId)
            ->where('idempotency_key', $key)
            ->first();

        if ($first === null) {
            return null;
        }

        $transactions = PaymentTransaction::query()
            ->withoutGlobalScopes()
            ->where('tenant_id', $tenantId)
            ->where('transaction_number', $first->transaction_number)
            ->orderBy('created_at')
            ->get();

        $lines = $transactions->map(fn (PaymentTransaction $tx) => new PaymentLineResult(
            transaction: $tx,
            status: $tx->status,
            providerReference: $tx->provider_reference,
            metadata: $tx->metadata ?? [],
        ))->all();

        $expectedTotal = $transactions->sum('amount');

        return new PaymentResult(
            transactionNumber: $first->transaction_number,
            expectedTotal: $expectedTotal,
            paidTotal: $expectedTotal,
            isMixed: $transactions->count() > 1,
            currency: $first->currency,
            lines: $lines,
            idempotencyKey: $key,
        );
    }

    private function nextTransactionNumber(string $tenantId): string
    {
        $prefix = config('payments.transaction_number_prefix', 'PAY');
        $count = PaymentTransaction::query()
            ->withoutGlobalScopes()
            ->where('tenant_id', $tenantId)
            ->distinct('transaction_number')
            ->count('transaction_number');

        return $prefix.'-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
