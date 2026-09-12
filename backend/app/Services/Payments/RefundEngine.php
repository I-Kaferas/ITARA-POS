<?php

namespace App\Services\Payments;

use App\DTOs\Payments\RefundContext;
use App\DTOs\Payments\RefundResult;
use App\Enums\PaymentProviderType;
use App\Enums\PaymentTransactionStatus;
use App\Enums\PaymentTransactionType;
use App\Enums\SaleRefundStatus;
use App\Enums\SaleReturnRefundMethod;
use App\Models\CashRegister;
use App\Models\Customer;
use App\Models\PaymentTransaction;
use App\Models\Sale;
use App\Models\SaleRefund;
use App\Models\SaleReturn;
use App\Models\User;
use App\Services\Audit\AuditLogService;
use App\Services\Authorization\AuthorizationService;
use App\Services\Customer\CustomerLedgerService;
use Illuminate\Validation\ValidationException;

class RefundEngine
{
    public function __construct(
        private readonly PaymentProviderRegistry $registry,
        private readonly CustomerLedgerService $customerLedger,
        private readonly AuditLogService $auditLogService,
        private readonly AuthorizationService $authorizationService,
    ) {}

    /**
     * @param  array{
     *     cash_register_id?: string|null,
     *     metadata?: array<string, mixed>,
     * }  $options
     */
    public function processForReturn(
        SaleReturn $saleReturn,
        Sale $sale,
        SaleReturnRefundMethod $refundMethod,
        User $user,
        array $options = [],
    ): ?RefundResult {
        if (! $refundMethod->isFinancial()) {
            return null;
        }

        if (! $this->authorizationService->hasPermission($user, 'sales.refund')) {
            throw ValidationException::withMessages([
                'refund_method' => ['You do not have permission to process refunds.'],
            ]);
        }

        if ($refundMethod->requiresCustomer() && $sale->customer_id === null) {
            throw ValidationException::withMessages([
                'refund_method' => ['Customer is required for this refund method.'],
            ]);
        }

        $customer = $sale->customer_id
            ? Customer::query()->findOrFail($sale->customer_id)
            : null;

        $cashRegister = $this->resolveCashRegister(
            $sale,
            $refundMethod,
            $options['cash_register_id'] ?? null,
        );

        $refundNumber = $this->nextRefundNumber($sale->tenant_id);
        $transactionNumber = $this->nextTransactionNumber($sale->tenant_id);

        $context = new RefundContext(
            store: $sale->store()->firstOrFail(),
            sale: $sale,
            saleReturn: $saleReturn,
            processedBy: $user,
            refundNumber: $refundNumber,
            transactionNumber: $transactionNumber,
            customer: $customer,
            cashRegister: $cashRegister,
            metadata: $options['metadata'] ?? [],
        );

        $originalTransaction = $this->findOriginalPaymentTransaction($sale, $refundMethod);

        $saleRefund = SaleRefund::query()->create([
            'tenant_id' => $sale->tenant_id,
            'sale_return_id' => $saleReturn->id,
            'sale_id' => $sale->id,
            'store_id' => $sale->store_id,
            'refund_number' => $refundNumber,
            'refund_method' => $refundMethod,
            'amount' => $saleReturn->total,
            'currency' => $saleReturn->currency,
            'status' => SaleRefundStatus::Completed,
            'cash_register_id' => $cashRegister?->id,
            'original_payment_transaction_id' => $originalTransaction?->id,
            'processed_by' => $user->id,
            'metadata' => $options['metadata'] ?? [],
            'completed_at' => now(),
        ]);

        $paymentMethod = $refundMethod->toPaymentMethod();

        if ($paymentMethod !== null) {
            $refundTransaction = PaymentTransaction::query()->create([
                'tenant_id' => $sale->tenant_id,
                'store_id' => $sale->store_id,
                'sale_id' => $sale->id,
                'sale_return_id' => $saleReturn->id,
                'original_transaction_id' => $originalTransaction?->id,
                'transaction_number' => $transactionNumber,
                'transaction_type' => PaymentTransactionType::Refund,
                'payment_method' => $paymentMethod,
                'amount' => $saleReturn->total,
                'currency' => $saleReturn->currency,
                'status' => PaymentTransactionStatus::Pending,
                'provider_type' => PaymentProviderType::forMethod($paymentMethod),
                'customer_id' => $customer?->id,
                'cash_register_id' => $cashRegister?->id,
                'processed_by' => $user->id,
                'metadata' => array_filter([
                    'sale_return_id' => $saleReturn->id,
                    'sale_refund_id' => $saleRefund->id,
                    'refund_number' => $refundNumber,
                ]),
            ]);

            $provider = $this->registry->resolve($paymentMethod);

            $lineResult = $provider->refund(
                originalTransaction: $originalTransaction ?? $refundTransaction,
                amount: $saleReturn->total,
                context: $context,
                refundTransaction: $refundTransaction,
            );

            $customerTransactionId = $lineResult->metadata['customer_transaction_id'] ?? null;

            $saleRefund->update([
                'payment_transaction_id' => $refundTransaction->id,
                'customer_transaction_id' => $customerTransactionId,
            ]);
        } elseif ($refundMethod === SaleReturnRefundMethod::Credit && $customer !== null) {
            $customerTransaction = $this->customerLedger->recordSaleReturn(
                customer: $customer,
                amount: $saleReturn->total,
                sale: $sale,
                reference: $saleReturn->return_number,
                description: "Store credit for return {$saleReturn->return_number} (sale {$sale->reference})",
                recordedBy: $user->id,
            );

            $saleRefund->update([
                'customer_transaction_id' => $customerTransaction->id,
            ]);
        }

        $saleRefund = $saleRefund->fresh([
            'paymentTransaction',
            'customerTransaction',
            'originalPaymentTransaction',
        ]);

        $this->auditLogService->log(
            action: 'sale_refund.processed',
            entity: $saleRefund,
            userId: $user->id,
            payload: [
                'sale_return_id' => $saleReturn->id,
                'sale_id' => $sale->id,
                'sale_reference' => $sale->reference,
                'return_number' => $saleReturn->return_number,
                'refund_number' => $saleRefund->refund_number,
                'refund_method' => $saleRefund->refund_method->value,
                'amount' => $saleRefund->amount,
                'payment_transaction_id' => $saleRefund->payment_transaction_id,
                'customer_transaction_id' => $saleRefund->customer_transaction_id,
                'original_payment_transaction_id' => $saleRefund->original_payment_transaction_id,
            ],
        );

        return new RefundResult($saleRefund);
    }

    private function resolveCashRegister(
        Sale $sale,
        SaleReturnRefundMethod $refundMethod,
        ?string $cashRegisterId,
    ): ?CashRegister {
        if (! $refundMethod->requiresCashRegister()) {
            return null;
        }

        $registerId = $cashRegisterId ?? $sale->cash_register_id;

        if ($registerId === null) {
            throw ValidationException::withMessages([
                'cash_register_id' => ['Cash register is required for cash refunds.'],
            ]);
        }

        $register = CashRegister::query()
            ->where('store_id', $sale->store_id)
            ->find($registerId);

        if ($register === null) {
            throw ValidationException::withMessages([
                'cash_register_id' => ['Cash register not found for this store.'],
            ]);
        }

        if ($register->openSession()->doesntExist()) {
            throw ValidationException::withMessages([
                'cash_register_id' => ['Cash register has no open session.'],
            ]);
        }

        return $register;
    }

    private function findOriginalPaymentTransaction(
        Sale $sale,
        SaleReturnRefundMethod $refundMethod,
    ): ?PaymentTransaction {
        $paymentMethod = $refundMethod->toPaymentMethod();

        if ($paymentMethod === null) {
            return null;
        }

        return PaymentTransaction::query()
            ->where('sale_id', $sale->id)
            ->where('payment_method', $paymentMethod)
            ->where('transaction_type', PaymentTransactionType::Payment)
            ->where('status', PaymentTransactionStatus::Completed)
            ->orderByDesc('completed_at')
            ->first();
    }

    private function nextRefundNumber(string $tenantId): string
    {
        $prefix = config('refunds.reference_prefix', 'RFD');
        $count = SaleRefund::query()->where('tenant_id', $tenantId)->count();

        return $prefix.'-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }

    private function nextTransactionNumber(string $tenantId): string
    {
        $prefix = config('payments.transaction_number_prefix', 'PAY');
        $count = PaymentTransaction::query()
            ->withoutGlobalScopes()
            ->where('tenant_id', $tenantId)
            ->distinct('transaction_number')
            ->count('transaction_number');

        return $prefix.'-R-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
