<?php

namespace App\Services\Purchase;

use App\Enums\GoodsReceiptStatus;
use App\Enums\InventoryMovementType;
use App\Enums\PurchaseInvoiceStatus;
use App\Enums\PurchaseOrderStatus;
use App\Enums\SupplierTransactionType;
use App\Events\PurchaseReceived;
use App\Models\GoodsReceipt;
use App\Models\GoodsReceiptItem;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseOrder;
use App\Models\PurchaseOrderItem;
use App\Models\Supplier;
use App\Models\User;
use App\Services\Accounting\AccountingEntryService;
use App\Services\Audit\AuditLogService;
use App\Services\Inventory\InventoryMovementService;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class GoodsReceiptService
{
    public function __construct(
        private readonly InventoryMovementService $movementService,
        private readonly SupplierLedgerService $ledgerService,
        private readonly AccountingEntryService $accountingService,
        private readonly AuditLogService $auditLogService,
        private readonly PurchaseOrderService $purchaseOrderService,
    ) {}

    /**
     * Receive goods against a purchase order.
     *
     * Chain: PO update → inventory movement → supplier balance → accounting → audit log
     *
     * @param  list<array{
     *     purchase_order_item_id: string,
     *     quantity: int,
     *     batch_id?: string|null,
     * }>  $items
     */
    public function receive(
        PurchaseOrder $purchaseOrder,
        array $items,
        ?User $receivedBy = null,
        ?string $notes = null,
    ): GoodsReceipt {
        if (! $purchaseOrder->status->canReceive()) {
            throw ValidationException::withMessages([
                'status' => ['Purchase order must be approved before receiving goods.'],
            ]);
        }

        if ($items === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required for receipt.'],
            ]);
        }

        $purchaseOrder->load(['items.product', 'warehouse', 'supplier']);

        if (! $purchaseOrder->warehouse) {
            throw ValidationException::withMessages([
                'warehouse_id' => ['Purchase order has no warehouse.'],
            ]);
        }

        return DB::transaction(function () use ($purchaseOrder, $items, $receivedBy, $notes): GoodsReceipt {
            $receipt = GoodsReceipt::query()->create([
                'tenant_id' => $purchaseOrder->tenant_id,
                'purchase_order_id' => $purchaseOrder->id,
                'warehouse_id' => $purchaseOrder->warehouse_id,
                'receipt_number' => $this->nextReceiptNumber($purchaseOrder->tenant_id),
                'status' => GoodsReceiptStatus::Completed,
                'received_by' => $receivedBy?->id,
                'received_at' => now(),
                'notes' => $notes,
            ]);

            $receiptSubtotal = 0;

            foreach ($items as $line) {
                /** @var PurchaseOrderItem $poItem */
                $poItem = $purchaseOrder->items->firstWhere('id', $line['purchase_order_item_id']);

                if (! $poItem) {
                    throw ValidationException::withMessages([
                        'items' => ['Invalid purchase order item.'],
                    ]);
                }

                $qty = (int) $line['quantity'];

                if ($qty <= 0) {
                    throw ValidationException::withMessages([
                        'items' => ['Quantity must be greater than zero.'],
                    ]);
                }

                if ($qty > $poItem->quantityRemaining()) {
                    throw ValidationException::withMessages([
                        'items' => ["Quantity exceeds remaining for product {$poItem->product->sku}."],
                    ]);
                }

                GoodsReceiptItem::query()->create([
                    'tenant_id' => $purchaseOrder->tenant_id,
                    'goods_receipt_id' => $receipt->id,
                    'purchase_order_item_id' => $poItem->id,
                    'product_id' => $poItem->product_id,
                    'product_variant_id' => $poItem->product_variant_id,
                    'batch_id' => $line['batch_id'] ?? null,
                    'quantity_received' => $qty,
                    'unit_cost' => $poItem->unit_cost,
                ]);

                $this->movementService->record([
                    'warehouse' => $purchaseOrder->warehouse,
                    'product' => $poItem->product,
                    'movement_type' => InventoryMovementType::Purchase,
                    'quantity' => $qty,
                    'unit_cost' => $poItem->unit_cost,
                    'product_variant_id' => $poItem->product_variant_id,
                    'batch_id' => $line['batch_id'] ?? null,
                    'reference' => $receipt,
                    'performed_by' => $receivedBy?->id,
                    'notes' => trim(($notes ? $notes.' · ' : '')."Réception {$receipt->receipt_number} · +{$qty}"),
                ]);

                $poItem->increment('quantity_received', $qty);
                $receiptSubtotal += $qty * $poItem->unit_cost;
            }

            $purchaseOrder->refresh();
            $purchaseOrder->load('items');

            $newStatus = $purchaseOrder->isFullyReceived()
                ? PurchaseOrderStatus::Received
                : PurchaseOrderStatus::PartiallyReceived;

            $purchaseOrder->update(['status' => $newStatus]);

            $invoice = null;
            if ($purchaseOrder->supplier && $receiptSubtotal > 0) {
                $invoice = $this->createInvoice($purchaseOrder, $receipt, $receiptSubtotal, $receivedBy);
                $this->accountingService->recordPurchaseReceipt(
                    reference: $receipt,
                    amount: $receiptSubtotal,
                    recordedBy: $receivedBy?->id,
                );
            }

            $this->auditLogService->log(
                action: 'goods_receipt.completed',
                entity: $receipt,
                userId: $receivedBy?->id,
                payload: [
                    'purchase_order_id' => $purchaseOrder->id,
                    'receipt_number' => $receipt->receipt_number,
                    'amount' => $receiptSubtotal,
                    'invoice_id' => $invoice?->id,
                ],
            );

            PurchaseReceived::dispatch($purchaseOrder->fresh(), $receipt->fresh(['items']));

            return $receipt->load(['items.product:id,sku,name', 'invoice']);
        });
    }

    private function createInvoice(
        PurchaseOrder $purchaseOrder,
        GoodsReceipt $receipt,
        int $subtotal,
        ?User $recordedBy,
    ): PurchaseInvoice {
        /** @var Supplier $supplier */
        $supplier = $purchaseOrder->supplier;

        $transaction = $this->ledgerService->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => $subtotal,
            'reference' => $receipt->receipt_number,
            'description' => "Goods receipt {$receipt->receipt_number} for PO {$purchaseOrder->order_number}",
            'due_date' => now()->addDays($supplier->payment_terms_days)->toDateString(),
            'purchase_order_id' => $purchaseOrder->id,
            'occurred_at' => $receipt->received_at,
            'recorded_by' => $recordedBy?->id,
        ]);

        return PurchaseInvoice::query()->create([
            'tenant_id' => $purchaseOrder->tenant_id,
            'purchase_order_id' => $purchaseOrder->id,
            'goods_receipt_id' => $receipt->id,
            'supplier_id' => $supplier->id,
            'supplier_transaction_id' => $transaction->id,
            'invoice_number' => $this->nextInvoiceNumber($purchaseOrder->tenant_id),
            'status' => PurchaseInvoiceStatus::Posted,
            'subtotal' => $subtotal,
            'tax_total' => 0,
            'total' => $subtotal,
            'paid_amount' => 0,
            'due_date' => now()->addDays($supplier->payment_terms_days),
            'invoiced_at' => now(),
        ]);
    }

    private function nextReceiptNumber(string $tenantId): string
    {
        $count = GoodsReceipt::query()->where('tenant_id', $tenantId)->count();

        return 'GRN-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }

    private function nextInvoiceNumber(string $tenantId): string
    {
        $count = PurchaseInvoice::query()->where('tenant_id', $tenantId)->count();

        return 'PI-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
