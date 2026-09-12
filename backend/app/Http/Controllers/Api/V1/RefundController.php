<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\SaleReturnRefundMethod;
use App\Http\Controllers\Controller;
use App\Models\SaleRefund;
use Illuminate\Http\JsonResponse;

class RefundController extends Controller
{
    public function methods(): JsonResponse
    {
        return response()->json([
            'data' => collect(SaleReturnRefundMethod::cases())
                ->map(fn (SaleReturnRefundMethod $method) => [
                    'value' => $method->value,
                    'label' => $method->label(),
                    'is_financial' => $method->isFinancial(),
                    'requires_customer' => $method->requiresCustomer(),
                    'requires_cash_register' => $method->requiresCashRegister(),
                ])
                ->values(),
        ]);
    }

    public function show(SaleRefund $saleRefund): JsonResponse
    {
        $saleRefund->load([
            'saleReturn:id,return_number,total',
            'sale:id,reference',
            'paymentTransaction',
            'customerTransaction',
            'originalPaymentTransaction',
            'processedBy:id,name',
        ]);

        return response()->json([
            'data' => [
                ...$saleRefund->toSummaryArray(),
                'sale_return' => $saleRefund->saleReturn?->only(['id', 'return_number', 'total']),
                'sale' => $saleRefund->sale?->only(['id', 'reference']),
                'payment_transaction' => $saleRefund->paymentTransaction?->toSummaryArray(),
                'customer_transaction' => $saleRefund->customerTransaction?->only([
                    'id', 'transaction_type', 'amount', 'reference', 'description',
                ]),
                'original_payment_transaction' => $saleRefund->originalPaymentTransaction?->toSummaryArray(),
                'processed_by' => $saleRefund->processedBy?->only(['id', 'name']),
            ],
        ]);
    }
}
