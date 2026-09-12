<?php

namespace App\Services\Purchase;

use App\Enums\PurchaseOrderStatus;
use App\Models\Product;
use App\Models\PurchaseOrder;
use App\Models\PurchaseOrderItem;
use App\Models\User;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PurchaseOrderService
{
    /**
     * @param  list<array{
     *     product_id: string,
     *     quantity: int,
     *     unit_cost: int,
     *     product_variant_id?: string|null,
     *     tax_rate?: float,
     * }>  $items
     */
    public function create(
        Warehouse $warehouse,
        array $items,
        ?string $supplierId = null,
        ?string $branchId = null,
        ?User $createdBy = null,
        ?string $notes = null,
        ?\DateTimeInterface $expectedAt = null,
    ): PurchaseOrder {
        if ($items === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required.'],
            ]);
        }

        return DB::transaction(function () use ($warehouse, $items, $supplierId, $branchId, $createdBy, $notes, $expectedAt): PurchaseOrder {
            $orderNumber = $this->nextOrderNumber($warehouse->tenant_id);

            $purchaseOrder = PurchaseOrder::query()->create([
                'tenant_id' => $warehouse->tenant_id,
                'branch_id' => $branchId ?? $warehouse->branch_id,
                'supplier_id' => $supplierId,
                'warehouse_id' => $warehouse->id,
                'order_number' => $orderNumber,
                'reference' => $orderNumber,
                'status' => PurchaseOrderStatus::Draft,
                'notes' => $notes,
                'expected_at' => $expectedAt,
                'created_by' => $createdBy?->id,
            ]);

            $this->syncItems($purchaseOrder, $items);
            $purchaseOrder->refreshTotals();

            return $purchaseOrder->load('items.product:id,sku,name');
        });
    }

    /**
     * @param  list<array{
     *     product_id: string,
     *     quantity: int,
     *     unit_cost: int,
     *     product_variant_id?: string|null,
     *     tax_rate?: float,
     * }>  $items
     */
    public function update(PurchaseOrder $purchaseOrder, array $items, ?string $notes = null, ?\DateTimeInterface $expectedAt = null): PurchaseOrder
    {
        if (! $purchaseOrder->status->canEdit()) {
            throw ValidationException::withMessages([
                'status' => ['Only draft purchase orders can be edited.'],
            ]);
        }

        return DB::transaction(function () use ($purchaseOrder, $items, $notes, $expectedAt): PurchaseOrder {
            $purchaseOrder->update(array_filter([
                'notes' => $notes,
                'expected_at' => $expectedAt,
            ], fn ($v) => $v !== null));

            $this->syncItems($purchaseOrder, $items);
            $purchaseOrder->refreshTotals();

            return $purchaseOrder->fresh(['items.product:id,sku,name']);
        });
    }

    public function submit(PurchaseOrder $purchaseOrder, ?User $confirmedBy = null): PurchaseOrder
    {
        if (! $purchaseOrder->status->canSubmit()) {
            throw ValidationException::withMessages([
                'status' => ['Purchase order cannot be submitted from its current status.'],
            ]);
        }

        if ($purchaseOrder->items()->count() === 0) {
            throw ValidationException::withMessages([
                'items' => ['Purchase order must have at least one item.'],
            ]);
        }

        $purchaseOrder->update([
            'status' => PurchaseOrderStatus::Pending,
            'submitted_at' => now(),
            'confirmed_by' => $confirmedBy?->id,
        ]);

        return $purchaseOrder->fresh();
    }

    public function approve(PurchaseOrder $purchaseOrder, ?User $approvedBy = null): PurchaseOrder
    {
        if (! $purchaseOrder->status->canApprove()) {
            throw ValidationException::withMessages([
                'status' => ['Only pending purchase orders can be approved.'],
            ]);
        }

        $purchaseOrder->update([
            'status' => PurchaseOrderStatus::Approved,
            'approved_at' => now(),
            'approved_by' => $approvedBy?->id,
            'ordered_at' => now(),
        ]);

        return $purchaseOrder->fresh();
    }

    public function cancel(PurchaseOrder $purchaseOrder): PurchaseOrder
    {
        if ($purchaseOrder->status->isTerminal()) {
            throw ValidationException::withMessages([
                'status' => ['Purchase order is already closed.'],
            ]);
        }

        if (in_array($purchaseOrder->status, [PurchaseOrderStatus::PartiallyReceived, PurchaseOrderStatus::Received], true)) {
            throw ValidationException::withMessages([
                'status' => ['Purchase orders with receipts cannot be cancelled.'],
            ]);
        }

        $purchaseOrder->update(['status' => PurchaseOrderStatus::Cancelled]);

        return $purchaseOrder->fresh();
    }

    public function markCompletedIfReady(PurchaseOrder $purchaseOrder): PurchaseOrder
    {
        $purchaseOrder->loadMissing(['items', 'invoices']);

        if (! $purchaseOrder->isFullyReceived()) {
            return $purchaseOrder;
        }

        $allInvoicesPaid = $purchaseOrder->invoices->every(
            fn ($invoice) => $invoice->outstandingAmount() === 0
        );

        if ($purchaseOrder->invoices->isNotEmpty() && $allInvoicesPaid) {
            $purchaseOrder->update([
                'status' => PurchaseOrderStatus::Completed,
                'completed_at' => now(),
            ]);
        }

        return $purchaseOrder->fresh();
    }

    /**
     * @param  list<array{
     *     product_id: string,
     *     quantity: int,
     *     unit_cost: int,
     *     product_variant_id?: string|null,
     *     tax_rate?: float,
     * }>  $items
     */
    private function syncItems(PurchaseOrder $purchaseOrder, array $items): void
    {
        $purchaseOrder->items()->delete();

        foreach ($items as $index => $item) {
            $product = Product::query()->findOrFail($item['product_id']);
            $product->assertStockable();
            $taxRate = (float) ($item['tax_rate'] ?? 0);
            $lineTotal = PurchaseOrderItem::computeLineTotal($item['quantity'], $item['unit_cost'], $taxRate);

            PurchaseOrderItem::query()->create([
                'tenant_id' => $purchaseOrder->tenant_id,
                'purchase_order_id' => $purchaseOrder->id,
                'product_id' => $product->id,
                'product_variant_id' => $item['product_variant_id'] ?? null,
                'quantity_ordered' => $item['quantity'],
                'quantity_received' => 0,
                'unit_cost' => $item['unit_cost'],
                'tax_rate' => $taxRate,
                'line_total' => $lineTotal,
                'sort_order' => $index,
            ]);
        }
    }

    private function nextOrderNumber(string $tenantId): string
    {
        $count = PurchaseOrder::query()->where('tenant_id', $tenantId)->count();

        return 'PO-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
