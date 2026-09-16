<?php

namespace App\Services\Purchase;

use App\Enums\PurchaseInvoiceStatus;
use App\Enums\PurchaseOrderStatus;
use App\Enums\PurchaseProformaStatus;
use App\Enums\PurchaseRequisitionPriority;
use App\Enums\PurchaseRequisitionStatus;
use App\Models\Product;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseOrder;
use App\Models\PurchaseOrderItem;
use App\Models\PurchasePayment;
use App\Models\PurchaseProforma;
use App\Models\PurchaseProformaItem;
use App\Models\PurchaseRequisition;
use App\Models\PurchaseRequisitionItem;
use App\Models\Supplier;
use App\Models\User;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PurchaseCycleService
{
    public function __construct(private readonly PurchaseOrderService $purchaseOrders) {}

    /** @return list<string> */
    public function requisitionRelations(): array
    {
        return [
            'warehouse:id,name,code',
            'supplier:id,name,code',
            'items.product:id,sku,name,cost_price',
            'convertedProforma:id,number,status',
            'convertedPurchaseOrder:id,order_number,status',
            'createdByUser:id,name',
            'approvedByUser:id,name',
        ];
    }

    /** @return list<string> */
    public function proformaRelations(): array
    {
        return [
            'warehouse:id,name,code',
            'supplier:id,name,code',
            'requisition:id,number,status',
            'items.product:id,sku,name,cost_price',
            'convertedPurchaseOrder:id,order_number,status',
            'createdByUser:id,name',
            'approvedByUser:id,name',
        ];
    }

    /**
     * @param  list<array{product_id: string, quantity: int, unit_cost?: int, product_variant_id?: string|null, tax_rate?: float}>  $items
     */
    public function createRequisition(array $payload, array $items, ?User $createdBy = null): PurchaseRequisition
    {
        $this->assertItems($items);

        return DB::transaction(function () use ($payload, $items, $createdBy): PurchaseRequisition {
            $warehouse = isset($payload['warehouse_id'])
                ? Warehouse::query()->findOrFail($payload['warehouse_id'])
                : null;

            $requisition = PurchaseRequisition::query()->create([
                'tenant_id' => $warehouse?->tenant_id ?? ($createdBy?->tenant_id),
                'branch_id' => $payload['branch_id'] ?? $warehouse?->branch_id,
                'warehouse_id' => $warehouse?->id,
                'supplier_id' => $payload['supplier_id'] ?? null,
                'number' => $this->nextNumber(PurchaseRequisition::class, 'REQ'),
                'status' => PurchaseRequisitionStatus::Draft,
                'priority' => $payload['priority'] ?? PurchaseRequisitionPriority::Normal->value,
                'department' => $payload['department'] ?? null,
                'needed_at' => $payload['needed_at'] ?? null,
                'reason' => $payload['reason'] ?? null,
                'notes' => $payload['notes'] ?? null,
                'created_by' => $createdBy?->id,
            ]);

            $this->syncRequisitionItems($requisition, $items);
            $requisition->refreshTotals();

            return $requisition->load($this->requisitionRelations());
        });
    }

    public function actRequisition(PurchaseRequisition $requisition, string $action, ?User $actor = null, ?string $comment = null): PurchaseRequisition
    {
        return match ($action) {
            'submit' => $this->submitRequisition($requisition, $actor),
            'approve' => $this->approveRequisition($requisition, $actor),
            'reject' => $this->rejectRequisition($requisition, $actor, $comment),
            default => throw ValidationException::withMessages([
                'action' => ['Unsupported requisition action.'],
            ]),
        };
    }

    /**
     * @return array{type: string, id: string, number: string}
     */
    public function convertRequisition(
        PurchaseRequisition $requisition,
        string $target,
        ?string $supplierId = null,
        ?string $warehouseId = null,
        ?User $actor = null,
    ): array {
        if (! $requisition->status->canConvert()) {
            throw ValidationException::withMessages([
                'status' => ['Only approved requisitions can be converted.'],
            ]);
        }

        $requisition->loadMissing('items');

        return DB::transaction(function () use ($requisition, $target, $supplierId, $warehouseId, $actor): array {
            if ($target === 'proforma') {
                $proforma = $this->createProformaFromRequisition($requisition, $supplierId, $actor);
                $requisition->update([
                    'status' => PurchaseRequisitionStatus::Converted,
                    'converted_at' => now(),
                    'converted_proforma_id' => $proforma->id,
                    'supplier_id' => $requisition->supplier_id ?? $proforma->supplier_id,
                ]);

                return ['type' => 'proforma', 'id' => $proforma->id, 'number' => $proforma->number];
            }

            if ($target === 'purchase_order') {
                $order = $this->createPurchaseOrderFromLines(
                    lines: $this->mapLines($requisition->items),
                    warehouseId: $warehouseId ?? $requisition->warehouse_id,
                    supplierId: $supplierId ?? $requisition->supplier_id,
                    branchId: $requisition->branch_id,
                    notes: $requisition->notes,
                    createdBy: $actor,
                    requisitionId: $requisition->id,
                );

                $requisition->update([
                    'status' => PurchaseRequisitionStatus::Converted,
                    'converted_at' => now(),
                    'converted_purchase_order_id' => $order->id,
                    'supplier_id' => $requisition->supplier_id ?? $order->supplier_id,
                    'warehouse_id' => $requisition->warehouse_id ?? $order->warehouse_id,
                ]);

                return ['type' => 'purchase_order', 'id' => $order->id, 'number' => $order->order_number];
            }

            throw ValidationException::withMessages([
                'target' => ['Conversion target must be proforma or purchase_order.'],
            ]);
        });
    }

    /**
     * @param  list<array{product_id: string, quantity: int, unit_cost?: int, product_variant_id?: string|null, tax_rate?: float}>  $items
     */
    public function createProforma(array $payload, array $items, ?User $createdBy = null): PurchaseProforma
    {
        $this->assertItems($items);

        return DB::transaction(function () use ($payload, $items, $createdBy): PurchaseProforma {
            $warehouse = isset($payload['warehouse_id'])
                ? Warehouse::query()->findOrFail($payload['warehouse_id'])
                : null;
            $supplier = Supplier::query()->findOrFail($payload['supplier_id']);

            $proforma = PurchaseProforma::query()->create([
                'tenant_id' => $warehouse?->tenant_id ?? $supplier->tenant_id,
                'branch_id' => $payload['branch_id'] ?? $warehouse?->branch_id,
                'warehouse_id' => $warehouse?->id,
                'supplier_id' => $supplier->id,
                'purchase_requisition_id' => $payload['purchase_requisition_id'] ?? null,
                'number' => $this->nextNumber(PurchaseProforma::class, 'PF'),
                'status' => PurchaseProformaStatus::Draft,
                'payment_terms' => $payload['payment_terms'] ?? null,
                'delivery_terms' => $payload['delivery_terms'] ?? null,
                'expires_at' => $payload['expires_at'] ?? null,
                'notes' => $payload['notes'] ?? null,
                'created_by' => $createdBy?->id,
            ]);

            $this->syncProformaItems($proforma, $items);
            $proforma->refreshTotals();

            return $proforma->load($this->proformaRelations());
        });
    }

    public function actProforma(PurchaseProforma $proforma, string $action, ?User $actor = null, ?string $comment = null): PurchaseProforma
    {
        $this->expireIfNeeded($proforma);

        return match ($action) {
            'send' => $this->sendProforma($proforma, $actor),
            'review' => $this->reviewProforma($proforma, $actor),
            'approve' => $this->approveProforma($proforma, $actor),
            'reject' => $this->rejectProforma($proforma, $actor, $comment),
            default => throw ValidationException::withMessages([
                'action' => ['Unsupported proforma action.'],
            ]),
        };
    }

    /**
     * @return array{id: string, number: string}
     */
    public function convertProforma(PurchaseProforma $proforma, string $warehouseId, ?User $actor = null): array
    {
        $this->expireIfNeeded($proforma);

        if (! $proforma->status->canConvert()) {
            throw ValidationException::withMessages([
                'status' => ['Only approved proformas can be converted into a purchase order.'],
            ]);
        }

        $proforma->loadMissing('items');

        return DB::transaction(function () use ($proforma, $warehouseId, $actor): array {
            $order = $this->createPurchaseOrderFromLines(
                lines: $this->mapLines($proforma->items),
                warehouseId: $warehouseId ?: $proforma->warehouse_id,
                supplierId: $proforma->supplier_id,
                branchId: $proforma->branch_id,
                notes: $proforma->notes,
                createdBy: $actor,
                requisitionId: $proforma->purchase_requisition_id,
                proformaId: $proforma->id,
            );

            $proforma->update([
                'status' => PurchaseProformaStatus::Converted,
                'converted_at' => now(),
                'converted_purchase_order_id' => $order->id,
                'warehouse_id' => $proforma->warehouse_id ?? $order->warehouse_id,
            ]);

            if ($proforma->purchase_requisition_id) {
                PurchaseRequisition::query()
                    ->where('id', $proforma->purchase_requisition_id)
                    ->whereNull('converted_purchase_order_id')
                    ->update([
                        'converted_purchase_order_id' => $order->id,
                        'status' => PurchaseRequisitionStatus::Converted,
                        'converted_at' => now(),
                    ]);
            }

            return ['id' => $order->id, 'number' => $order->order_number];
        });
    }

    /**
     * @param  array{from?: string|null, to?: string|null, supplier_id?: string|null, warehouse_id?: string|null}  $filters
     * @return array<string, mixed>
     */
    public function overview(array $filters): array
    {
        $from = $filters['from'] ?? null;
        $to = $filters['to'] ?? null;
        $supplierId = $filters['supplier_id'] ?? null;
        $warehouseId = $filters['warehouse_id'] ?? null;

        $orders = PurchaseOrder::query()
            ->when($supplierId, fn ($q) => $q->where('supplier_id', $supplierId))
            ->when($warehouseId, fn ($q) => $q->where('warehouse_id', $warehouseId))
            ->get();

        $periodOrders = $orders->filter(function (PurchaseOrder $order) use ($from, $to) {
            if ($order->status === PurchaseOrderStatus::Cancelled) {
                return false;
            }
            $date = optional($order->created_at)->toDateString();
            if ($from && $date < $from) {
                return false;
            }
            if ($to && $date > $to) {
                return false;
            }

            return true;
        });

        $invoices = PurchaseInvoice::query()
            ->when($supplierId, fn ($q) => $q->where('supplier_id', $supplierId))
            ->get();

        $monthStart = now()->startOfMonth()->toDateString();
        $monthOrders = $orders->filter(function (PurchaseOrder $order) use ($monthStart) {
            if ($order->status === PurchaseOrderStatus::Cancelled) {
                return false;
            }

            return optional($order->created_at)->toDateString() >= $monthStart;
        });

        $payments = PurchasePayment::query()
            ->when($from || $to, function ($query) use ($from, $to) {
                if ($from) {
                    $query->whereDate('paid_at', '>=', $from);
                }
                if ($to) {
                    $query->whereDate('paid_at', '<=', $to);
                }
            })
            ->when($supplierId, function ($query) use ($supplierId) {
                $query->whereHas('invoice', fn ($invoice) => $invoice->where('supplier_id', $supplierId));
            })
            ->get();

        $topSuppliers = $periodOrders
            ->filter(fn (PurchaseOrder $order) => $order->supplier_id)
            ->groupBy('supplier_id')
            ->map(function ($group, $supplierId) {
                $first = $group->first();
                $first?->loadMissing('supplier:id,name');

                return [
                    'supplier_id' => $supplierId,
                    'name' => $first?->supplier?->name,
                    'orders' => $group->count(),
                    'amount' => (int) $group->sum('total'),
                ];
            })
            ->sortByDesc('amount')
            ->take(8)
            ->values()
            ->all();

        $pendingRequisitionStatuses = [
            PurchaseRequisitionStatus::Draft->value,
            PurchaseRequisitionStatus::Submitted->value,
        ];
        $pendingProformaStatuses = [
            PurchaseProformaStatus::Draft->value,
            PurchaseProformaStatus::Sent->value,
            PurchaseProformaStatus::UnderReview->value,
        ];

        return [
            'purchases_total' => (int) $periodOrders->sum('total'),
            'pending_purchases' => $orders->filter(
                fn (PurchaseOrder $order) => in_array($order->status, [PurchaseOrderStatus::Draft, PurchaseOrderStatus::Pending], true)
            )->count(),
            'pending_requisitions' => PurchaseRequisition::query()
                ->whereIn('status', $pendingRequisitionStatuses)
                ->when($warehouseId, fn ($q) => $q->where('warehouse_id', $warehouseId))
                ->when($supplierId, fn ($q) => $q->where('supplier_id', $supplierId))
                ->count(),
            'pending_proformas' => PurchaseProforma::query()
                ->whereIn('status', $pendingProformaStatuses)
                ->when($warehouseId, fn ($q) => $q->where('warehouse_id', $warehouseId))
                ->when($supplierId, fn ($q) => $q->where('supplier_id', $supplierId))
                ->count(),
            'open_orders' => $orders->filter(
                fn (PurchaseOrder $order) => in_array($order->status, [PurchaseOrderStatus::Approved, PurchaseOrderStatus::PartiallyReceived], true)
            )->count(),
            'unpaid_invoices' => $invoices->where('status', PurchaseInvoiceStatus::Posted)->count(),
            'partial_invoices' => $invoices->where('status', PurchaseInvoiceStatus::PartiallyPaid)->count(),
            'amount_due' => (int) $invoices
                ->filter(fn (PurchaseInvoice $invoice) => $invoice->status !== PurchaseInvoiceStatus::Cancelled)
                ->sum(fn (PurchaseInvoice $invoice) => $invoice->outstandingAmount()),
            'payments_total' => (int) $payments->sum('amount'),
            'returns_total' => 0,
            'month_purchases' => (int) $monthOrders->sum('total'),
            'top_suppliers' => $topSuppliers,
        ];
    }

    private function submitRequisition(PurchaseRequisition $requisition, ?User $actor): PurchaseRequisition
    {
        if (! $requisition->status->canSubmit()) {
            throw ValidationException::withMessages([
                'status' => ['Only draft requisitions can be submitted.'],
            ]);
        }

        if ($requisition->items()->count() === 0) {
            throw ValidationException::withMessages([
                'items' => ['A requisition must have at least one item.'],
            ]);
        }

        $requisition->update([
            'status' => PurchaseRequisitionStatus::Submitted,
            'submitted_at' => now(),
            'submitted_by' => $actor?->id,
        ]);

        return $requisition->fresh($this->requisitionRelations());
    }

    private function approveRequisition(PurchaseRequisition $requisition, ?User $actor): PurchaseRequisition
    {
        if (! $requisition->status->canApprove()) {
            throw ValidationException::withMessages([
                'status' => ['Only submitted requisitions can be approved.'],
            ]);
        }

        $requisition->update([
            'status' => PurchaseRequisitionStatus::Approved,
            'approved_at' => now(),
            'approved_by' => $actor?->id,
        ]);

        return $requisition->fresh($this->requisitionRelations());
    }

    private function rejectRequisition(PurchaseRequisition $requisition, ?User $actor, ?string $comment): PurchaseRequisition
    {
        if (! $requisition->status->canReject()) {
            throw ValidationException::withMessages([
                'status' => ['Only submitted requisitions can be rejected.'],
            ]);
        }

        $requisition->update([
            'status' => PurchaseRequisitionStatus::Rejected,
            'rejected_at' => now(),
            'rejected_by' => $actor?->id,
            'rejection_comment' => $comment,
        ]);

        return $requisition->fresh($this->requisitionRelations());
    }

    private function sendProforma(PurchaseProforma $proforma, ?User $actor): PurchaseProforma
    {
        if (! $proforma->status->canSend()) {
            throw ValidationException::withMessages([
                'status' => ['Only draft proformas can be sent.'],
            ]);
        }

        $proforma->update([
            'status' => PurchaseProformaStatus::Sent,
            'sent_at' => now(),
            'sent_by' => $actor?->id,
        ]);

        return $proforma->fresh($this->proformaRelations());
    }

    private function reviewProforma(PurchaseProforma $proforma, ?User $actor): PurchaseProforma
    {
        if (! $proforma->status->canReview()) {
            throw ValidationException::withMessages([
                'status' => ['Only sent proformas can be reviewed.'],
            ]);
        }

        $proforma->update([
            'status' => PurchaseProformaStatus::UnderReview,
            'reviewed_at' => now(),
            'reviewed_by' => $actor?->id,
        ]);

        return $proforma->fresh($this->proformaRelations());
    }

    private function approveProforma(PurchaseProforma $proforma, ?User $actor): PurchaseProforma
    {
        if (! $proforma->status->canApprove()) {
            throw ValidationException::withMessages([
                'status' => ['Only proformas under review can be approved.'],
            ]);
        }

        $proforma->update([
            'status' => PurchaseProformaStatus::Approved,
            'approved_at' => now(),
            'approved_by' => $actor?->id,
        ]);

        return $proforma->fresh($this->proformaRelations());
    }

    private function rejectProforma(PurchaseProforma $proforma, ?User $actor, ?string $comment): PurchaseProforma
    {
        if (! $proforma->status->canReject()) {
            throw ValidationException::withMessages([
                'status' => ['This proforma cannot be rejected from its current status.'],
            ]);
        }

        $proforma->update([
            'status' => PurchaseProformaStatus::Rejected,
            'rejected_at' => now(),
            'rejected_by' => $actor?->id,
            'rejection_comment' => $comment,
        ]);

        return $proforma->fresh($this->proformaRelations());
    }

    private function expireIfNeeded(PurchaseProforma $proforma): void
    {
        if ($proforma->isExpired() && $proforma->status !== PurchaseProformaStatus::Expired) {
            $proforma->update(['status' => PurchaseProformaStatus::Expired]);
            $proforma->refresh();
        }

        if ($proforma->status === PurchaseProformaStatus::Expired) {
            throw ValidationException::withMessages([
                'status' => ['This proforma has expired.'],
            ]);
        }
    }

    private function createProformaFromRequisition(PurchaseRequisition $requisition, ?string $supplierId, ?User $actor): PurchaseProforma
    {
        $supplierId ??= $requisition->supplier_id;
        if (! $supplierId) {
            throw ValidationException::withMessages([
                'supplier_id' => ['A supplier is required to convert a requisition into a proforma.'],
            ]);
        }

        return $this->createProforma([
            'warehouse_id' => $requisition->warehouse_id,
            'branch_id' => $requisition->branch_id,
            'supplier_id' => $supplierId,
            'purchase_requisition_id' => $requisition->id,
            'notes' => $requisition->notes,
        ], $this->mapLines($requisition->items), $actor);
    }

    /**
     * @param  list<array{product_id: string, quantity: int, unit_cost: int, product_variant_id?: string|null, tax_rate?: float}>  $lines
     */
    private function createPurchaseOrderFromLines(
        array $lines,
        ?string $warehouseId,
        ?string $supplierId,
        ?string $branchId,
        ?string $notes,
        ?User $createdBy,
        ?string $requisitionId = null,
        ?string $proformaId = null,
    ): PurchaseOrder {
        if (! $warehouseId) {
            throw ValidationException::withMessages([
                'warehouse_id' => ['A warehouse is required to create a purchase order.'],
            ]);
        }
        if (! $supplierId) {
            throw ValidationException::withMessages([
                'supplier_id' => ['A supplier is required to create a purchase order.'],
            ]);
        }

        $warehouse = Warehouse::query()->findOrFail($warehouseId);
        $priced = array_map(function (array $line) {
            if (($line['unit_cost'] ?? 0) > 0) {
                return $line;
            }
            $product = Product::query()->findOrFail($line['product_id']);
            $line['unit_cost'] = (int) ($product->cost_price ?? 0);

            return $line;
        }, $lines);

        $order = $this->purchaseOrders->create(
            warehouse: $warehouse,
            items: $priced,
            supplierId: $supplierId,
            branchId: $branchId,
            createdBy: $createdBy,
            notes: $notes,
        );

        $order->update(array_filter([
            'purchase_requisition_id' => $requisitionId,
            'purchase_proforma_id' => $proformaId,
        ]));

        // The requisition/proforma was already approved: the supply must be
        // ready to receive, otherwise stock never moves from the purchase cycle.
        $order = $this->purchaseOrders->submit($order);
        $order = $this->purchaseOrders->approve($order, $createdBy);

        return $order->fresh(['items.product:id,sku,name']);
    }

    /**
     * @param  iterable<int, object{product_id: string, quantity: int, unit_cost: int, product_variant_id?: string|null, tax_rate?: float|string|null}>  $items
     * @return list<array{product_id: string, quantity: int, unit_cost: int, product_variant_id?: string|null, tax_rate?: float}>
     */
    private function mapLines(iterable $items): array
    {
        $lines = [];
        foreach ($items as $item) {
            $lines[] = [
                'product_id' => $item->product_id,
                'quantity' => (int) $item->quantity,
                'unit_cost' => (int) $item->unit_cost,
                'product_variant_id' => $item->product_variant_id ?? null,
                'tax_rate' => (float) ($item->tax_rate ?? 0),
            ];
        }

        return $lines;
    }

    /**
     * @param  list<array{product_id: string, quantity: int, unit_cost?: int, product_variant_id?: string|null, tax_rate?: float}>  $items
     */
    private function syncRequisitionItems(PurchaseRequisition $requisition, array $items): void
    {
        $requisition->items()->delete();

        foreach ($items as $index => $item) {
            $product = Product::query()->findOrFail($item['product_id']);
            $product->assertStockable();
            $taxRate = (float) ($item['tax_rate'] ?? 0);
            $unitCost = (int) ($item['unit_cost'] ?? $product->cost_price ?? 0);
            $quantity = (int) $item['quantity'];

            PurchaseRequisitionItem::query()->create([
                'tenant_id' => $requisition->tenant_id,
                'purchase_requisition_id' => $requisition->id,
                'product_id' => $product->id,
                'product_variant_id' => $item['product_variant_id'] ?? null,
                'quantity' => $quantity,
                'unit_cost' => $unitCost,
                'tax_rate' => $taxRate,
                'line_total' => PurchaseOrderItem::computeLineTotal($quantity, $unitCost, $taxRate),
                'sort_order' => $index,
            ]);
        }
    }

    /**
     * @param  list<array{product_id: string, quantity: int, unit_cost?: int, product_variant_id?: string|null, tax_rate?: float}>  $items
     */
    private function syncProformaItems(PurchaseProforma $proforma, array $items): void
    {
        $proforma->items()->delete();

        foreach ($items as $index => $item) {
            $product = Product::query()->findOrFail($item['product_id']);
            $product->assertStockable();
            $taxRate = (float) ($item['tax_rate'] ?? 0);
            $unitCost = (int) ($item['unit_cost'] ?? $product->cost_price ?? 0);
            $quantity = (int) $item['quantity'];

            PurchaseProformaItem::query()->create([
                'tenant_id' => $proforma->tenant_id,
                'purchase_proforma_id' => $proforma->id,
                'product_id' => $product->id,
                'product_variant_id' => $item['product_variant_id'] ?? null,
                'quantity' => $quantity,
                'unit_cost' => $unitCost,
                'tax_rate' => $taxRate,
                'line_total' => PurchaseOrderItem::computeLineTotal($quantity, $unitCost, $taxRate),
                'sort_order' => $index,
            ]);
        }
    }

    /**
     * @param  list<array{product_id: string, quantity: int}>  $items
     */
    private function assertItems(array $items): void
    {
        if ($items === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required.'],
            ]);
        }
    }

    /**
     * @param  class-string<PurchaseRequisition|PurchaseProforma>  $model
     */
    private function nextNumber(string $model, string $prefix): string
    {
        $count = $model::query()->withTrashed()->count();

        return $prefix.'-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
