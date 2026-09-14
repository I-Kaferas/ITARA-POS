<?php

namespace App\Services\Sales;

use App\DTOs\Sales\SaleReturnResult;
use App\Enums\InventoryMovementType;
use App\Enums\SaleReturnRefundMethod;
use App\Enums\SaleReturnStatus;
use App\Enums\SaleStatus;
use App\Events\SaleReturnCompleted;
use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SaleReturn;
use App\Models\SaleReturnItem;
use App\Models\Store;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Accounting\AccountingEntryService;
use App\Services\Customer\CustomerLoyaltyService;
use App\Services\Audit\AuditLogService;
use App\Services\Inventory\InventoryMovementService;
use App\Services\Payments\RefundEngine;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SaleReturnEngine
{
    public function __construct(
        private readonly InventoryMovementService $movementService,
        private readonly RefundEngine $refundEngine,
        private readonly AccountingEntryService $accountingService,
        private readonly AuditLogService $auditLogService,
        private readonly CustomerLoyaltyService $loyalty,
    ) {}

    /**
     * Process a sale return transactionally.
     *
     * Workflow: Original Sale → Select Items → Reason → Approve → Restock → Refund/Credit
     *
     * @param  array{
     *     items: list<array{sale_item_id: string, quantity: int, batch_id?: string|null}>,
     *     reason: string,
     *     refund_method?: string,
     *     cash_register_id?: string|null,
     *     refund_metadata?: array<string, mixed>|null,
     *     notes?: string|null,
     *     idempotency_key?: string|null,
     * }  $payload
     */
    public function create(Sale $sale, array $payload, User $user): SaleReturnResult
    {
        $idempotencyKey = $payload['idempotency_key'] ?? null;

        if ($idempotencyKey !== null) {
            $existing = SaleReturn::query()
                ->where('tenant_id', $sale->tenant_id)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if ($existing !== null) {
                return new SaleReturnResult($existing->load(['items', 'sale']));
            }
        }

        if (($payload['items'] ?? []) === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required for a return.'],
            ]);
        }

        if (empty($payload['reason'])) {
            throw ValidationException::withMessages([
                'reason' => ['A return reason is required.'],
            ]);
        }

        $this->assertSaleReturnable($sale);

        return DB::transaction(function () use ($sale, $payload, $user, $idempotencyKey): SaleReturnResult {
            $sale->load(['items.product', 'warehouse', 'customer']);

            $validatedLines = $this->validateReturnItems($sale, $payload['items']);
            $totals = $this->calculateTotals($validatedLines);
            $refundMethod = SaleReturnRefundMethod::tryFrom($payload['refund_method'] ?? 'none')
                ?? SaleReturnRefundMethod::None;

            if ($refundMethod === SaleReturnRefundMethod::Credit && $sale->customer_id === null) {
                throw ValidationException::withMessages([
                    'refund_method' => ['Customer is required for store credit refunds.'],
                ]);
            }

            if ($refundMethod === SaleReturnRefundMethod::Wallet && $sale->customer_id === null) {
                throw ValidationException::withMessages([
                    'refund_method' => ['Customer is required for wallet refunds.'],
                ]);
            }

            $warehouse = $this->resolveWarehouse($sale);

            $saleReturn = SaleReturn::query()->create([
                'tenant_id' => $sale->tenant_id,
                'sale_id' => $sale->id,
                'store_id' => $sale->store_id,
                'warehouse_id' => $warehouse->id,
                'customer_id' => $sale->customer_id,
                'return_number' => $this->nextReturnNumber($sale->tenant_id),
                'status' => SaleReturnStatus::Completed,
                'reason' => $payload['reason'],
                'refund_method' => $refundMethod,
                'subtotal' => $totals['subtotal'],
                'tax_total' => $totals['tax_total'],
                'discount_total' => $totals['discount_total'],
                'total' => $totals['total'],
                'currency' => $sale->currency,
                'processed_by' => $user->id,
                'approved_by' => $user->id,
                'idempotency_key' => $idempotencyKey,
                'approved_at' => now(),
                'completed_at' => now(),
                'notes' => $payload['notes'] ?? null,
            ]);

            $returnItems = $this->createReturnItems($saleReturn, $validatedLines);
            $this->restock($saleReturn, $warehouse, $returnItems, $user);
            $refundResult = $this->refundEngine->processForReturn(
                saleReturn: $saleReturn,
                sale: $sale,
                refundMethod: $refundMethod,
                user: $user,
                options: [
                    'cash_register_id' => $payload['cash_register_id'] ?? null,
                    'metadata' => $payload['refund_metadata'] ?? [],
                ],
            );
            $this->accountingService->recordSaleReturn($saleReturn, $user->id);
            if ($sale->customer !== null) {
                $this->loyalty->reverseForReturn($sale->customer, $sale, (int) $saleReturn->total, $user->id);
            }

            $this->auditLogService->log(
                action: 'sale_return.completed',
                entity: $saleReturn,
                userId: $user->id,
                payload: [
                    'sale_id' => $sale->id,
                    'sale_reference' => $sale->reference,
                    'return_number' => $saleReturn->return_number,
                    'total' => $saleReturn->total,
                    'reason' => $saleReturn->reason,
                    'refund_method' => $saleReturn->refund_method->value,
                    'refund_id' => $refundResult?->saleRefund->id,
                    'refund_number' => $refundResult?->saleRefund->refund_number,
                ],
            );

            $saleReturn = $saleReturn->fresh(['items', 'sale', 'customer', 'refunds']);

            SaleReturnCompleted::dispatch($saleReturn);

            return new SaleReturnResult($saleReturn);
        });
    }

    public function find(string $saleReturnId): SaleReturn
    {
        return SaleReturn::query()
            ->with(['items', 'sale', 'customer', 'processedBy', 'approvedBy', 'refunds'])
            ->findOrFail($saleReturnId);
    }

    /** @return Collection<int, SaleReturn> */
    public function listForSale(Sale $sale): Collection
    {
        return SaleReturn::query()
            ->where('sale_id', $sale->id)
            ->orderByDesc('completed_at')
            ->get();
    }

    /** @return Collection<int, SaleReturn> */
    public function listForStore(Store $store, int $limit = 50): Collection
    {
        return SaleReturn::query()
            ->where('store_id', $store->id)
            ->with(['sale:id,reference,total', 'customer:id,name'])
            ->orderByDesc('created_at')
            ->limit($limit)
            ->get();
    }

    private function assertSaleReturnable(Sale $sale): void
    {
        if ($sale->status !== SaleStatus::Completed) {
            throw ValidationException::withMessages([
                'sale_id' => ['Only completed sales can be returned.'],
            ]);
        }
    }

    /**
     * @param  list<array{sale_item_id: string, quantity: int, batch_id?: string|null}>  $items
     * @return list<array{
     *     sale_item: SaleItem,
     *     quantity: int,
     *     batch_id: string|null,
     *     line_subtotal: int,
     *     line_tax: int,
     *     line_total: int,
     * }>
     */
    private function validateReturnItems(Sale $sale, array $items): array
    {
        $validated = [];
        $seenSaleItemIds = [];

        foreach ($items as $index => $line) {
            $saleItemId = $line['sale_item_id'] ?? null;
            $quantity = (int) ($line['quantity'] ?? 0);

            if ($saleItemId === null) {
                throw ValidationException::withMessages([
                    "items.{$index}.sale_item_id" => ['Sale item is required.'],
                ]);
            }

            if (isset($seenSaleItemIds[$saleItemId])) {
                throw ValidationException::withMessages([
                    "items.{$index}.sale_item_id" => ['Duplicate sale item in return request.'],
                ]);
            }

            $seenSaleItemIds[$saleItemId] = true;

            if ($quantity <= 0) {
                throw ValidationException::withMessages([
                    "items.{$index}.quantity" => ['Quantity must be greater than zero.'],
                ]);
            }

            /** @var SaleItem|null $saleItem */
            $saleItem = $sale->items->firstWhere('id', $saleItemId);

            if ($saleItem === null) {
                throw ValidationException::withMessages([
                    "items.{$index}.sale_item_id" => ['Sale item does not belong to this sale.'],
                ]);
            }

            $returnable = $saleItem->quantityReturnable();

            if ($quantity > $returnable) {
                throw ValidationException::withMessages([
                    "items.{$index}.quantity" => [
                        "Return quantity ({$quantity}) exceeds returnable quantity ({$returnable}) for {$saleItem->product_name}.",
                    ],
                ]);
            }

            $amounts = $this->proportionalLineAmounts($saleItem, $quantity);

            $validated[] = [
                'sale_item' => $saleItem,
                'quantity' => $quantity,
                'batch_id' => $line['batch_id'] ?? null,
                ...$amounts,
            ];
        }

        return $validated;
    }

    /** @return array{line_subtotal: int, line_tax: int, line_total: int, discount_share: int} */
    private function proportionalLineAmounts(SaleItem $saleItem, int $quantity): array
    {
        if ($quantity >= $saleItem->quantity) {
            return [
                'line_subtotal' => $saleItem->line_subtotal,
                'line_tax' => $saleItem->line_tax,
                'line_total' => $saleItem->line_total,
                'discount_share' => 0,
            ];
        }

        $lineSubtotal = intdiv($saleItem->line_subtotal * $quantity, $saleItem->quantity);
        $lineTax = intdiv($saleItem->line_tax * $quantity, $saleItem->quantity);
        $lineTotal = intdiv($saleItem->line_total * $quantity, $saleItem->quantity);

        return [
            'line_subtotal' => $lineSubtotal,
            'line_tax' => $lineTax,
            'line_total' => $lineTotal,
            'discount_share' => max(0, $lineSubtotal + $lineTax - $lineTotal),
        ];
    }

    /**
     * @param  list<array{
     *     sale_item: SaleItem,
     *     quantity: int,
     *     batch_id: string|null,
     *     line_subtotal: int,
     *     line_tax: int,
     *     line_total: int,
     *     discount_share: int,
     * }>  $lines
     * @return array{subtotal: int, tax_total: int, discount_total: int, total: int}
     */
    private function calculateTotals(array $lines): array
    {
        $subtotal = 0;
        $taxTotal = 0;
        $discountTotal = 0;
        $total = 0;

        foreach ($lines as $line) {
            $subtotal += $line['line_subtotal'];
            $taxTotal += $line['line_tax'];
            $discountTotal += $line['discount_share'];
            $total += $line['line_total'];
        }

        return [
            'subtotal' => $subtotal,
            'tax_total' => $taxTotal,
            'discount_total' => $discountTotal,
            'total' => $total,
        ];
    }

    /**
     * @param  list<array{
     *     sale_item: SaleItem,
     *     quantity: int,
     *     batch_id: string|null,
     *     line_subtotal: int,
     *     line_tax: int,
     *     line_total: int,
     * }>  $validatedLines
     * @return list<SaleReturnItem>
     */
    private function createReturnItems(SaleReturn $saleReturn, array $validatedLines): array
    {
        $items = [];

        foreach ($validatedLines as $index => $line) {
            /** @var SaleItem $saleItem */
            $saleItem = $line['sale_item'];

            $items[] = SaleReturnItem::query()->create([
                'tenant_id' => $saleReturn->tenant_id,
                'sale_return_id' => $saleReturn->id,
                'sale_item_id' => $saleItem->id,
                'product_id' => $saleItem->product_id,
                'product_variant_id' => $saleItem->product_variant_id,
                'product_name' => $saleItem->product_name,
                'product_sku' => $saleItem->product_sku,
                'quantity_returned' => $line['quantity'],
                'unit_price' => $saleItem->unit_price,
                'tax_rate' => $saleItem->tax_rate,
                'line_subtotal' => $line['line_subtotal'],
                'line_tax' => $line['line_tax'],
                'line_total' => $line['line_total'],
                'batch_id' => $line['batch_id'],
                'sort_order' => $index,
            ]);
        }

        return $items;
    }

    /** @param  list<SaleReturnItem>  $returnItems */
    private function restock(
        SaleReturn $saleReturn,
        Warehouse $warehouse,
        array $returnItems,
        User $user,
    ): void {
        foreach ($returnItems as $returnItem) {
            if ($returnItem->product_id === null) {
                continue;
            }

            $product = Product::query()->find($returnItem->product_id);

            if ($product === null || ! $product->requiresStock()) {
                continue;
            }

            $this->movementService->record([
                'warehouse' => $warehouse,
                'product' => $product,
                'movement_type' => InventoryMovementType::SaleReturn,
                'quantity' => $returnItem->quantity_returned,
                'product_variant_id' => $returnItem->product_variant_id,
                'batch_id' => $returnItem->batch_id,
                'unit_cost' => $product->cost_price,
                'reference' => $saleReturn,
                'performed_by' => $user->id,
                'notes' => "Retour {$saleReturn->return_number} · +{$returnItem->quantity_returned}",
            ]);
        }
    }

    private function resolveWarehouse(Sale $sale): Warehouse
    {
        if ($sale->warehouse_id !== null) {
            $warehouse = Warehouse::query()->find($sale->warehouse_id);

            if ($warehouse !== null) {
                return $warehouse;
            }
        }

        throw ValidationException::withMessages([
            'warehouse_id' => ['Sale has no warehouse for restocking.'],
        ]);
    }

    private function nextReturnNumber(string $tenantId): string
    {
        $prefix = config('returns.reference_prefix', 'RTN');
        $count = SaleReturn::query()->where('tenant_id', $tenantId)->count();

        return $prefix.'-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
