<?php

namespace App\Services\Purchase;

use App\Enums\PurchaseInvoiceStatus;
use App\Enums\SupplierPaymentMethod;
use App\Models\PurchaseInvoice;
use App\Models\PurchasePayment;
use App\Models\User;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PurchasePaymentService
{
    public function __construct(
        private readonly SupplierLedgerService $ledgerService,
        private readonly PurchaseOrderService $purchaseOrderService,
    ) {}

    public function record(
        PurchaseInvoice $invoice,
        int $amount,
        SupplierPaymentMethod $method = SupplierPaymentMethod::BankTransfer,
        ?string $reference = null,
        ?string $notes = null,
        ?User $recordedBy = null,
    ): PurchasePayment {
        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['Payment amount must be greater than zero.'],
            ]);
        }

        if ($amount > $invoice->outstandingAmount()) {
            throw ValidationException::withMessages([
                'amount' => ['Payment exceeds invoice outstanding amount.'],
            ]);
        }

        $invoice->loadMissing(['supplier', 'purchaseOrder']);

        return DB::transaction(function () use ($invoice, $amount, $method, $reference, $notes, $recordedBy): PurchasePayment {
            $supplierPayment = $this->ledgerService->recordPayment(
                supplier: $invoice->supplier,
                amount: $amount,
                method: $method,
                allocations: $invoice->supplier_transaction_id
                    ? [['transaction_id' => $invoice->supplier_transaction_id, 'amount' => $amount]]
                    : null,
                reference: $reference,
                notes: $notes,
                recordedBy: $recordedBy?->id,
            );

            $payment = PurchasePayment::query()->create([
                'tenant_id' => $invoice->tenant_id,
                'purchase_invoice_id' => $invoice->id,
                'supplier_payment_id' => $supplierPayment->id,
                'payment_number' => $this->nextPaymentNumber($invoice->tenant_id),
                'amount' => $amount,
                'payment_method' => $method->value,
                'reference' => $reference,
                'notes' => $notes,
                'paid_at' => now(),
                'recorded_by' => $recordedBy?->id,
            ]);

            $newPaid = $invoice->paid_amount + $amount;
            $status = $newPaid >= $invoice->total
                ? PurchaseInvoiceStatus::Paid
                : PurchaseInvoiceStatus::PartiallyPaid;

            $invoice->update([
                'paid_amount' => $newPaid,
                'status' => $status,
            ]);

            if ($invoice->purchaseOrder) {
                $this->purchaseOrderService->markCompletedIfReady($invoice->purchaseOrder);
            }

            return $payment->load('invoice');
        });
    }

    private function nextPaymentNumber(string $tenantId): string
    {
        $count = PurchasePayment::query()->where('tenant_id', $tenantId)->count();

        return 'PPY-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
