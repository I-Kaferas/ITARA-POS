<?php

namespace App\Services\Receipts;

use App\Enums\SaleDocumentFormat;
use App\Enums\SalePaymentMethod;
use App\Models\Sale;
use App\Models\SaleInvoice;
use App\Models\SaleReceipt;

class ReceiptPayloadService
{
    /**
     * Build a structured print payload from a sale.
     *
     * @return array<string, mixed>
     */
    public function build(
        Sale $sale,
        SaleDocumentFormat $format,
        ?SaleReceipt $receipt = null,
        ?SaleInvoice $invoice = null,
    ): array {
        $sale->loadMissing([
            'store.branch.company',
            'items',
            'payments.paymentTransaction',
            'taxes',
            'discounts',
            'customer',
            'processedBy',
        ]);

        $store = $sale->store;
        $branch = $store?->branch;
        $company = $branch?->company;
        $settings = $company?->settings ?? [];

        $payments = $this->buildPayments($sale);
        $amountPaid = array_sum(array_column($payments, 'amount'));
        $change = $this->resolveChange($payments);

        $documentType = $invoice !== null ? 'invoice' : 'receipt';
        $documentNumber = $invoice?->invoice_number
            ?? $receipt?->receipt_number
            ?? $sale->reference;

        return [
            'document_type' => $documentType,
            'format' => $format->value,
            'format_label' => $format->label(),
            'company' => [
                'name' => $company?->name,
                'trade_name' => $company?->trade_name,
                'legal_name' => $company?->legal_name,
                'legal_form' => $company?->legal_form,
                'tax_id' => $company?->tax_id,
                'registration_number' => $company?->registration_number,
                'phone' => $company?->phone,
                'email' => $company?->email,
                'website' => $company?->website,
                'logo_url' => $company?->logo_url,
                'address' => $company?->address,
                'currency_code' => $company?->currency_code ?? $sale->currency,
                'receipt_footer' => $settings['receipt_footer'] ?? null,
                'legal_mentions' => $settings['legal_mentions'] ?? null,
            ],
            'branch' => [
                'name' => $branch?->name,
                'code' => $branch?->code,
                'address' => $branch?->address,
            ],
            'store' => [
                'name' => $store?->name,
                'code' => $store?->code,
            ],
            'receipt_number' => $receipt?->receipt_number,
            'invoice_number' => $invoice?->invoice_number,
            'document_number' => $documentNumber,
            'sale_reference' => $sale->reference,
            'sale_id' => $sale->id,
            'date' => ($sale->completed_at ?? $sale->created_at)?->toIso8601String(),
            'cashier' => $sale->processedBy?->only(['id', 'name']),
            'customer' => $sale->customer?->only(['id', 'name', 'email', 'phone']),
            'items' => $sale->items->map(fn ($item) => [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'product_variant_id' => $item->product_variant_id,
                'name' => $item->product_name,
                'sku' => $item->product_sku,
                'quantity' => $item->quantity,
                'unit_price' => $item->unit_price,
                'line_subtotal' => $item->line_subtotal,
                'line_discount' => $this->lineDiscount($sale, $item->id),
                'line_tax' => $item->line_tax,
                'line_total' => $item->line_total,
            ])->values()->all(),
            'subtotal' => $sale->subtotal,
            'discount_total' => $sale->discount_total,
            'tax_total' => $sale->tax_total,
            'fees_total' => $sale->fees_total,
            'total' => $sale->total,
            'currency' => $sale->currency,
            'taxes' => $sale->taxes->map(fn ($tax) => [
                'name' => $tax->tax_name,
                'rate' => $tax->tax_rate,
                'taxable_amount' => $tax->taxable_amount,
                'amount' => $tax->tax_amount,
            ])->values()->all(),
            'discounts' => $sale->discounts->map(fn ($discount) => [
                'label' => $discount->label,
                'type' => $discount->discount_type->value,
                'amount' => $discount->amount,
                'sale_item_id' => $discount->sale_item_id,
            ])->values()->all(),
            'payments' => $payments,
            'amount_paid' => $amountPaid,
            'change' => $change,
            'footer' => $settings['receipt_footer'] ?? null,
            'notes' => $sale->notes,
        ];
    }

  /** @return list<array<string, mixed>> */
    private function buildPayments(Sale $sale): array
    {
        return $sale->payments->map(function ($payment) {
            $transaction = $payment->paymentTransaction;
            $metadata = $transaction?->metadata ?? [];
            $method = SalePaymentMethod::tryFrom($payment->payment_method);

            return [
                'method' => $payment->payment_method,
                'method_label' => $method?->label() ?? $payment->payment_method,
                'amount' => $payment->amount,
                'currency' => $payment->currency,
                'tendered' => $metadata['tendered'] ?? null,
                'change' => $metadata['change'] ?? null,
                'transaction_number' => $transaction?->transaction_number,
            ];
        })->values()->all();
    }

    /** @param  list<array<string, mixed>>  $payments */
    private function resolveChange(array $payments): int
    {
        $change = 0;

        foreach ($payments as $payment) {
            if (isset($payment['change'])) {
                $change += (int) $payment['change'];
            }
        }

        return $change;
    }

    private function lineDiscount(Sale $sale, string $saleItemId): int
    {
        return (int) $sale->discounts
            ->where('sale_item_id', $saleItemId)
            ->sum('amount');
    }
}
