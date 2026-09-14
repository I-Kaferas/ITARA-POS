<?php

namespace App\DTOs\Sales;

use App\DTOs\Cart\CartCalculationResult;
use App\DTOs\Payments\PaymentResult;
use App\Models\Sale;

final readonly class SaleResult
{
    public function __construct(
        public Sale $sale,
        public CartCalculationResult $cart,
        public PaymentResult $payment,
        public ?array $receipt = null,
        public ?array $syncEvent = null,
        public ?array $loyalty = null,
    ) {}

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        $sale = $this->sale->load([
            'items',
            'payments.paymentTransaction',
            'taxes',
            'discounts',
            'customer:id,name',
            'processedBy:id,name',
            'installments',
        ]);

        return [
            'sale' => [
                ...$sale->toSummaryArray(),
                'items' => $sale->items->map(fn ($item) => [
                    'id' => $item->id,
                    'product_id' => $item->product_id,
                    'product_variant_id' => $item->product_variant_id,
                    'product_name' => $item->product_name,
                    'product_sku' => $item->product_sku,
                    'quantity' => $item->quantity,
                    'unit_price' => $item->unit_price,
                    'price_type' => $item->price_type,
                    'line_subtotal' => $item->line_subtotal,
                    'line_tax' => $item->line_tax,
                    'line_total' => $item->line_total,
                ])->values()->all(),
                'payments' => $sale->payments->map(fn ($payment) => [
                    'id' => $payment->id,
                    'payment_method' => $payment->payment_method,
                    'amount' => $payment->amount,
                    'currency' => $payment->currency,
                    'transaction_number' => $payment->paymentTransaction?->transaction_number,
                ])->values()->all(),
                'taxes' => $sale->taxes->map(fn ($tax) => [
                    'id' => $tax->id,
                    'sale_item_id' => $tax->sale_item_id,
                    'tax_name' => $tax->tax_name,
                    'tax_rate' => $tax->tax_rate,
                    'taxable_amount' => $tax->taxable_amount,
                    'tax_amount' => $tax->tax_amount,
                ])->values()->all(),
                'discounts' => $sale->discounts->map(fn ($discount) => [
                    'id' => $discount->id,
                    'sale_item_id' => $discount->sale_item_id,
                    'discount_type' => $discount->discount_type->value,
                    'source' => $discount->source->value,
                    'label' => $discount->label,
                    'amount' => $discount->amount,
                ])->values()->all(),
                'installments' => $sale->installments->map(fn ($installment) => [
                    'id' => $installment->id,
                    'installment_number' => $installment->installment_number,
                    'amount' => $installment->amount,
                    'paid_amount' => $installment->paid_amount,
                    'outstanding_amount' => $installment->outstandingAmount(),
                    'due_date' => $installment->due_date->toDateString(),
                    'status' => $installment->status->value,
                ])->values()->all(),
                'credit' => [
                    'paid_amount' => $sale->paid_amount,
                    'outstanding_amount' => $sale->outstandingAmount(),
                    'due_date' => $sale->due_date?->toDateString(),
                    'payment_status' => $sale->payment_status->value,
                ],
            ],
            'cart' => $this->cart->toArray(),
            'payment' => [
                'transaction_number' => $this->payment->transactionNumber,
                'paid_total' => $this->payment->paidTotal,
                'outstanding_amount' => max(0, $this->sale->total - $this->sale->paid_amount),
                'is_mixed' => $this->payment->isMixed,
                'lines' => array_map(fn ($line) => $line->toArray(), $this->payment->lines),
            ],
            'receipt' => $this->receipt,
            'sync_event' => $this->syncEvent,
            'loyalty' => $this->loyalty,
        ];
    }
}
