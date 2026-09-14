<?php

namespace App\Services\Sales;

use App\DTOs\Cart\CartCalculationResult;
use App\DTOs\Payments\PaymentLineResult;
use App\DTOs\Payments\PaymentResult;
use App\DTOs\Sales\SaleResult;
use App\Enums\InventoryMovementType;
use App\Enums\SaleDiscountSource;
use App\Enums\SaleDiscountType;
use App\Enums\SaleDocumentFormat;
use App\Enums\SalePaymentMethod;
use App\Enums\SalePaymentStatus;
use App\Enums\SaleStatus;
use App\Events\SaleCompleted;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleDiscount;
use App\Models\SaleItem;
use App\Models\SalePayment;
use App\Models\SaleReceipt;
use App\Models\SaleTax;
use App\Models\SyncEvent;
use App\Models\Store;
use App\Models\StoreProduct;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Accounting\AccountingEntryService;
use App\Services\Customer\CustomerLoyaltyService;
use App\Services\Audit\AuditLogService;
use App\Services\Inventory\InventoryMovementService;
use App\Services\Inventory\StockBalanceService;
use App\Services\Payments\PaymentEngine;
use App\Services\Promotions\PromotionEngine;
use App\Services\Receipts\ReceiptPayloadService;
use App\Services\Receipts\SaleReceiptService;
use App\Services\Shifts\CashierShiftService;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SaleEngine
{
    public function __construct(
        private readonly CartEngine $cartEngine,
        private readonly PaymentEngine $paymentEngine,
        private readonly InventoryMovementService $movementService,
        private readonly StockBalanceService $stockBalanceService,
        private readonly AccountingEntryService $accountingService,
        private readonly AuditLogService $auditLogService,
        private readonly SaleCreditService $creditService,
        private readonly CashierShiftService $cashierShiftService,
        private readonly SaleReceiptService $receipts,
        private readonly ReceiptPayloadService $receiptPayloads,
        private readonly PromotionEngine $promotionEngine,
        private readonly CustomerLoyaltyService $loyalty,
    ) {}

    /** @param  array<string, mixed>  $payload */
    public function create(Store $store, array $payload, User $user): SaleResult
    {
        $idempotencyKey = $payload['idempotency_key'] ?? null;

        if ($idempotencyKey !== null) {
            $existing = Sale::query()
                ->where('tenant_id', $store->tenant_id)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if ($existing !== null) {
                return $this->buildExistingResult($existing);
            }
        }

        if (($payload['items'] ?? []) === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required.'],
            ]);
        }

        if (($payload['payments'] ?? []) === []) {
            throw ValidationException::withMessages([
                'payments' => ['At least one payment line is required.'],
            ]);
        }

        return DB::transaction(function () use ($store, $payload, $user, $idempotencyKey): SaleResult {
            $this->validateProducts($store, $payload);

            $cart = $this->cartEngine->calculateForStore($store, $payload);

            $warehouse = $this->resolveWarehouse($store, $payload['warehouse_id'] ?? null);
            $this->validateStock($warehouse, $cart);

            $sale = Sale::query()->create([
                'tenant_id' => $store->tenant_id,
                'store_id' => $store->id,
                'customer_id' => $payload['customer_id'] ?? null,
                'warehouse_id' => $warehouse->id,
                'cash_register_id' => $payload['cash_register_id'] ?? null,
                'cashier_shift_id' => $payload['cashier_shift_id'] ?? null,
                'device_id' => $payload['device_id'] ?? null,
                'processed_by' => $user->id,
                'reference' => $this->nextReference($store->tenant_id),
                'status' => SaleStatus::Completed,
                'subtotal' => $cart->subtotal,
                'tax_total' => $cart->taxTotal,
                'discount_total' => $cart->discountTotal,
                'fees_total' => $cart->feesTotal,
                'total' => $cart->grandTotal,
                'currency' => $cart->currency,
                'idempotency_key' => $idempotencyKey,
                'completed_at' => now(),
                'notes' => $payload['notes'] ?? null,
            ]);

            $saleItems = $this->createSaleItems($sale, $cart);
            $this->createSaleTaxes($sale, $saleItems, $cart);
            $this->createSaleDiscounts($sale, $saleItems, $cart);
            $this->promotionEngine->recordUsage($cart->promotions);

            $paymentResult = $this->paymentEngine->processForSale($store, $payload, $user, $sale);

            $sale->update(['payment_transaction_number' => $paymentResult->transactionNumber]);

            $this->createSalePayments($sale, $paymentResult);

            $immediatePaid = 0;
            $creditAmount = 0;

            foreach ($paymentResult->lines as $line) {
                if ($line->transaction->payment_method === SalePaymentMethod::Credit) {
                    $creditAmount += $line->transaction->amount;
                } else {
                    $immediatePaid += $line->transaction->amount;
                }
            }

            $dueDate = $payload['due_date'] ?? null;

            $sale->update([
                'paid_amount' => $immediatePaid,
                'due_date' => $dueDate,
                'payment_status' => SalePaymentStatus::fromAmounts($sale->total, $immediatePaid),
            ]);

            if ($creditAmount > 0 && isset($payload['installments'])) {
                $this->creditService->createInstallments($sale, $creditAmount, $payload['installments']);
            }

            $this->decreaseInventory($sale, $warehouse, $cart, $user);
            $this->accountingService->recordSale($sale, $user->id);
            $this->cashierShiftService->recordCompletedSale($sale, $user);
            $loyalty = $this->applyCustomerLoyalty($sale, $payload, $user);

            $sealed = $this->sealCompletedSale($sale, $user, $payload['device_id'] ?? null);

            $this->auditLogService->log(
                action: 'sale.completed',
                entity: $sale,
                userId: $user->id,
                payload: [
                    'reference' => $sale->reference,
                    'total' => $sale->total,
                    'payment_transaction_number' => $paymentResult->transactionNumber,
                    'item_count' => count($cart->lines),
                    'receipt_number' => $sealed['receipt']->receipt_number,
                    'sync_event_id' => $sealed['sync_event']->id,
                ],
            );

            $sale = $sale->fresh(['items', 'payments', 'taxes', 'discounts', 'installments', 'receipts']);

            return new SaleResult($sale, $cart, $paymentResult, $sealed['payload'], $sealed['sync_event']->toSummaryArray(), $loyalty);
        });
    }

    /** @param  array<string, mixed>  $payload */
    public function hold(Store $store, array $payload, User $user): Sale
    {
        if (($payload['items'] ?? []) === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required.'],
            ]);
        }

        return DB::transaction(function () use ($store, $payload, $user): Sale {
            $sale = $this->writePendingSale($store, $payload, $user);

            $this->auditLogService->log(
                action: 'sale.held',
                entity: $sale,
                userId: $user->id,
                payload: [
                    'reference' => $sale->reference,
                    'total' => $sale->total,
                ],
            );

            return $sale->fresh(['items', 'customer', 'discounts']);
        });
    }

    /** @param  array<string, mixed>  $payload */
    public function updateHold(Sale $sale, array $payload, User $user): Sale
    {
        $this->assertPending($sale);

        if (($payload['items'] ?? []) === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required.'],
            ]);
        }

        return DB::transaction(function () use ($sale, $payload, $user): Sale {
            $store = $sale->store ?? Store::query()->findOrFail($sale->store_id);
            $this->replacePendingContents($sale, $store, $payload);

            $this->auditLogService->log(
                action: 'sale.held_updated',
                entity: $sale,
                userId: $user->id,
                payload: [
                    'reference' => $sale->reference,
                    'total' => $sale->total,
                ],
            );

            return $sale->fresh(['items', 'customer', 'discounts']);
        });
    }

    public function discardHold(Sale $sale, User $user): void
    {
        $this->assertPending($sale);

        $this->auditLogService->log(
            action: 'sale.held_discarded',
            entity: $sale,
            userId: $user->id,
            payload: ['reference' => $sale->reference],
        );

        $sale->delete();
    }

    /** @param  array<string, mixed>  $payload */
    public function completePending(Store $store, array $payload, User $user): SaleResult
    {
        $sale = Sale::query()
            ->where('store_id', $store->id)
            ->findOrFail($payload['sale_id']);

        $this->assertPending($sale);

        if (($payload['payments'] ?? []) === []) {
            throw ValidationException::withMessages([
                'payments' => ['At least one payment line is required.'],
            ]);
        }

        return DB::transaction(function () use ($store, $payload, $user, $sale): SaleResult {
            $this->validateProducts($store, $payload);

            $cart = $this->cartEngine->calculateForStore($store, $payload);
            $warehouse = $this->resolveWarehouse($store, $payload['warehouse_id'] ?? $sale->warehouse_id);
            $this->validateStock($warehouse, $cart);

            $this->clearSaleLines($sale);

            $sale->update([
                'customer_id' => $payload['customer_id'] ?? null,
                'warehouse_id' => $warehouse->id,
                'cash_register_id' => $payload['cash_register_id'] ?? $sale->cash_register_id,
                'cashier_shift_id' => $payload['cashier_shift_id'] ?? $sale->cashier_shift_id,
                'device_id' => $payload['device_id'] ?? $sale->device_id,
                'processed_by' => $user->id,
                'status' => SaleStatus::Completed,
                'subtotal' => $cart->subtotal,
                'tax_total' => $cart->taxTotal,
                'discount_total' => $cart->discountTotal,
                'fees_total' => $cart->feesTotal,
                'total' => $cart->grandTotal,
                'currency' => $cart->currency,
                'idempotency_key' => $payload['idempotency_key'] ?? $sale->idempotency_key,
                'completed_at' => now(),
                'notes' => $payload['notes'] ?? $sale->notes,
            ]);

            $saleItems = $this->createSaleItems($sale, $cart);
            $this->createSaleTaxes($sale, $saleItems, $cart);
            $this->createSaleDiscounts($sale, $saleItems, $cart);
            $this->promotionEngine->recordUsage($cart->promotions);

            $paymentResult = $this->paymentEngine->processForSale($store, $payload, $user, $sale);
            $sale->update(['payment_transaction_number' => $paymentResult->transactionNumber]);
            $this->createSalePayments($sale, $paymentResult);

            $immediatePaid = 0;
            $creditAmount = 0;

            foreach ($paymentResult->lines as $line) {
                if ($line->transaction->payment_method === SalePaymentMethod::Credit) {
                    $creditAmount += $line->transaction->amount;
                } else {
                    $immediatePaid += $line->transaction->amount;
                }
            }

            $sale->update([
                'paid_amount' => $immediatePaid,
                'due_date' => $payload['due_date'] ?? null,
                'payment_status' => SalePaymentStatus::fromAmounts($sale->total, $immediatePaid),
            ]);

            if ($creditAmount > 0 && isset($payload['installments'])) {
                $this->creditService->createInstallments($sale, $creditAmount, $payload['installments']);
            }

            $this->decreaseInventory($sale, $warehouse, $cart, $user);
            $this->accountingService->recordSale($sale, $user->id);
            $this->cashierShiftService->recordCompletedSale($sale, $user);
            $loyalty = $this->applyCustomerLoyalty($sale, $payload, $user);

            $sealed = $this->sealCompletedSale($sale, $user, $payload['device_id'] ?? $sale->device_id);

            $this->auditLogService->log(
                action: 'sale.completed',
                entity: $sale,
                userId: $user->id,
                payload: [
                    'reference' => $sale->reference,
                    'total' => $sale->total,
                    'from_pending' => true,
                    'receipt_number' => $sealed['receipt']->receipt_number,
                    'sync_event_id' => $sealed['sync_event']->id,
                ],
            );

            $sale = $sale->fresh(['items', 'payments', 'taxes', 'discounts', 'installments', 'receipts']);

            return new SaleResult($sale, $cart, $paymentResult, $sealed['payload'], $sealed['sync_event']->toSummaryArray(), $loyalty);
        });
    }

    public function find(string $saleId): Sale
    {
        return Sale::query()
            ->with(['items', 'payments.paymentTransaction', 'taxes', 'discounts', 'customer', 'processedBy', 'installments'])
            ->findOrFail($saleId);
    }

    /**
     * @param  array{
     *     limit?: int,
     *     q?: string|null,
     *     status?: string|null,
     *     payment_status?: string|null,
     *     customer_id?: string|null,
     *     from?: string|null,
     *     to?: string|null
     * }  $filters
     * @return Collection<int, Sale>
     */
    public function listForStore(Store $store, array $filters = []): Collection
    {
        $limit = min(200, max(1, (int) ($filters['limit'] ?? 50)));

        $query = Sale::query()
            ->with(['customer:id,name,email', 'processedBy:id,name'])
            ->where('store_id', $store->id);

        $this->applySaleListFilters($query, $filters);

        return $query
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit($limit)
            ->get();
    }

    /**
     * @param  array{
     *     q?: string|null,
     *     status?: string|null,
     *     payment_status?: string|null,
     *     customer_id?: string|null,
     *     from?: string|null,
     *     to?: string|null
     * }  $filters
     * @return \Illuminate\Database\Eloquent\Builder<Sale>
     */
    public function queryForStore(Store $store, array $filters = [])
    {
        $query = Sale::query()
            ->with(['customer:id,name', 'store:id,name,code', 'processedBy:id,name'])
            ->where('store_id', $store->id);

        $this->applySaleListFilters($query, $filters);

        return $query->orderByDesc('created_at')->orderByDesc('id');
    }

    /**
     * @param  \Illuminate\Database\Eloquent\Builder<Sale>  $query
     * @param  array<string, mixed>  $filters
     */
    private function applySaleListFilters($query, array $filters): void
    {
        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (! empty($filters['payment_status'])) {
            $query->where('payment_status', $filters['payment_status']);
        }

        if (! empty($filters['customer_id'])) {
            $query->where('customer_id', $filters['customer_id']);
        }

        if (! empty($filters['from'])) {
            $query->where(function ($q) use ($filters) {
                $from = \Illuminate\Support\Carbon::parse($filters['from'])->startOfDay();
                $q->where('completed_at', '>=', $from)
                    ->orWhere(function ($inner) use ($from) {
                        $inner->whereNull('completed_at')->where('created_at', '>=', $from);
                    });
            });
        }

        if (! empty($filters['to'])) {
            $query->where(function ($q) use ($filters) {
                $to = \Illuminate\Support\Carbon::parse($filters['to'])->endOfDay();
                $q->where('completed_at', '<=', $to)
                    ->orWhere(function ($inner) use ($to) {
                        $inner->whereNull('completed_at')->where('created_at', '<=', $to);
                    });
            });
        }

        if (! empty($filters['q'])) {
            $term = trim((string) $filters['q']);
            $query->where(function ($q) use ($term) {
                $q->where('reference', 'like', "%{$term}%")
                    ->orWhere('notes', 'like', "%{$term}%")
                    ->orWhereHas('customer', function ($customer) use ($term) {
                        $customer->where('name', 'like', "%{$term}%")
                            ->orWhere('email', 'like', "%{$term}%")
                            ->orWhere('phone', 'like', "%{$term}%")
                            ->orWhere('code', 'like', "%{$term}%");
                    });
            });
        }
    }

    private function buildExistingResult(Sale $sale): SaleResult
    {
        $sale->load(['items', 'payments.paymentTransaction', 'taxes', 'discounts']);

        $paymentLines = $sale->paymentTransactions()
            ->orderBy('created_at')
            ->get()
            ->map(fn ($tx) => new PaymentLineResult(
                transaction: $tx,
                status: $tx->status,
                providerReference: $tx->provider_reference,
                metadata: $tx->metadata ?? [],
            ))
            ->all();

        $paymentResult = new PaymentResult(
            transactionNumber: $sale->payment_transaction_number ?? '',
            expectedTotal: $sale->total,
            paidTotal: $sale->total,
            isMixed: count($paymentLines) > 1,
            currency: $sale->currency,
            lines: $paymentLines,
            idempotencyKey: $sale->idempotency_key,
        );

        $cart = new CartCalculationResult(
            subtotal: $sale->subtotal,
            lineDiscountsTotal: 0,
            promotionDiscountsTotal: 0,
            globalDiscountTotal: 0,
            discountTotal: $sale->discount_total,
            taxTotal: $sale->tax_total,
            feesTotal: $sale->fees_total,
            grandTotal: $sale->total,
            lines: [],
            fees: [],
            currency: $sale->currency,
        );

        $sale->loadMissing(['receipts']);
        $receipt = $sale->receipts->first();
        $event = $sale->syncEvents()->first();

        return new SaleResult(
            $sale,
            $cart,
            $paymentResult,
            $receipt ? $this->receiptPayloads->build($sale, $receipt->format, $receipt) : null,
            $event?->toSummaryArray(),
        );
    }

    /** @param  array<string, mixed>  $payload */
    private function validateProducts(Store $store, array $payload): void
    {
        foreach ($payload['items'] ?? [] as $index => $item) {
            if (! isset($item['product_id'])) {
                continue;
            }

            $storeProduct = StoreProduct::query()
                ->where('store_id', $store->id)
                ->where('product_id', $item['product_id'])
                ->first()
                ?? app(\App\Services\Catalog\PosCatalogSyncService::class)->ensureStoreProduct($store, $item['product_id']);

            if ($storeProduct === null) {
                throw ValidationException::withMessages([
                    "items.{$index}.product_id" => ['Product is not available in this store.'],
                ]);
            }

            if (! $storeProduct->is_available) {
                throw ValidationException::withMessages([
                    "items.{$index}.product_id" => ['Product is not available for sale in this store.'],
                ]);
            }

            $product = Product::query()->find($item['product_id']);

            if ($product === null || ! $product->is_active) {
                throw ValidationException::withMessages([
                    "items.{$index}.product_id" => ['Product is inactive or does not exist.'],
                ]);
            }
        }
    }

    private function validateStock(Warehouse $warehouse, CartCalculationResult $cart): void
    {
        $demand = [];

        foreach ($cart->lines as $line) {
            if ($line->productId === null) {
                continue;
            }

            $key = $line->productId.'|'.($line->productVariantId ?? '');
            $demand[$key]['product_id'] = $line->productId;
            $demand[$key]['variant_id'] = $line->productVariantId;
            $demand[$key]['name'] = $line->name;
            $demand[$key]['quantity'] = ($demand[$key]['quantity'] ?? 0) + $line->stockQuantity();
        }

        foreach ($demand as $row) {
            $product = Product::query()->find($row['product_id']);

            if ($product === null || ! $product->requiresStock()) {
                continue;
            }

            $available = $this->stockBalanceService->availableQuantity(
                warehouse: $warehouse,
                product: $product,
                productVariantId: $row['variant_id'],
            );

            if ($available < $row['quantity']) {
                throw ValidationException::withMessages([
                    'stock' => ["Stock insuffisant pour {$row['name']}. Disponible: {$available}, demandé: {$row['quantity']}."],
                ]);
            }
        }
    }

    private function resolveWarehouse(Store $store, ?string $warehouseId): Warehouse
    {
        $store->loadMissing('branch');

        if ($warehouseId !== null) {
            $warehouse = Warehouse::query()
                ->where('branch_id', $store->branch_id)
                ->where('is_active', true)
                ->find($warehouseId);

            if ($warehouse === null) {
                throw ValidationException::withMessages([
                    'warehouse_id' => ['Warehouse not found for this store branch.'],
                ]);
            }

            return $warehouse;
        }

        $warehouse = Warehouse::query()
            ->where('branch_id', $store->branch_id)
            ->where('is_active', true)
            ->orderBy('created_at')
            ->first();

        if ($warehouse === null) {
            throw ValidationException::withMessages([
                'warehouse_id' => ['No active warehouse found for this store branch.'],
            ]);
        }

        return $warehouse;
    }

    /** @return array<string, SaleItem> keyed by cart line_id */
    private function createSaleItems(Sale $sale, CartCalculationResult $cart): array
    {
        $items = [];

        foreach ($cart->lines as $index => $line) {
            $saleItem = SaleItem::query()->create([
                'tenant_id' => $sale->tenant_id,
                'sale_id' => $sale->id,
                'product_id' => $line->productId,
                'product_variant_id' => $line->productVariantId,
                'product_name' => $line->name ?? 'Item',
                'product_sku' => $line->sku,
                'quantity' => $line->quantity,
                'sale_unit_id' => $line->saleUnitId,
                'sale_unit_name' => $line->saleUnitId ? $line->name : null,
                'volume_ml' => $line->volumeMl ? $line->quantity * $line->volumeMl : null,
                'unit_price' => $line->unitPrice,
                'price_type' => $line->priceType ?? 'retail',
                'catalog_price' => $line->unitPrice,
                'tax_rate' => $line->taxRate,
                'line_subtotal' => $line->lineSubtotal,
                'line_tax' => $line->lineTax,
                'line_total' => $line->lineTotal,
                'sort_order' => $index,
            ]);

            $items[$line->lineId] = $saleItem;
        }

        return $items;
    }

    /** @param  array<string, SaleItem>  $saleItems */
    private function createSaleTaxes(Sale $sale, array $saleItems, CartCalculationResult $cart): void
    {
        $sortOrder = 0;

        foreach ($cart->lines as $line) {
            if ($line->lineTax <= 0) {
                continue;
            }

            $product = $line->productId ? Product::query()->with('tax')->find($line->productId) : null;

            SaleTax::query()->create([
                'tenant_id' => $sale->tenant_id,
                'sale_id' => $sale->id,
                'sale_item_id' => $saleItems[$line->lineId]->id ?? null,
                'tax_id' => $product?->tax_id,
                'tax_name' => $product?->tax?->name,
                'tax_rate' => $line->taxRate,
                'taxable_amount' => $line->taxableNet,
                'tax_amount' => $line->lineTax,
                'sort_order' => $sortOrder++,
            ]);
        }
    }

    /** @param  array<string, SaleItem>  $saleItems */
    private function createSaleDiscounts(Sale $sale, array $saleItems, CartCalculationResult $cart): void
    {
        $sortOrder = 0;

        foreach ($cart->lines as $line) {
            if ($line->lineDiscount > 0) {
                SaleDiscount::query()->create([
                    'tenant_id' => $sale->tenant_id,
                    'sale_id' => $sale->id,
                    'sale_item_id' => $saleItems[$line->lineId]->id ?? null,
                    'discount_type' => SaleDiscountType::Line,
                    'source' => SaleDiscountSource::Manual,
                    'label' => 'Line discount',
                    'amount' => $line->lineDiscount,
                    'sort_order' => $sortOrder++,
                ]);
            }

            if ($line->promotionDiscount > 0) {
                $applied = collect($cart->promotions)->first(
                    fn (array $row) => ($row['line_id'] ?? null) === $line->lineId && (int) ($row['amount'] ?? 0) > 0,
                );

                SaleDiscount::query()->create([
                    'tenant_id' => $sale->tenant_id,
                    'sale_id' => $sale->id,
                    'sale_item_id' => $saleItems[$line->lineId]->id ?? null,
                    'promotion_id' => $applied['promotion_id'] ?? null,
                    'discount_type' => SaleDiscountType::Promotion,
                    'source' => SaleDiscountSource::Promotion,
                    'label' => $applied['name'] ?? 'Promotion discount',
                    'amount' => $line->promotionDiscount,
                    'sort_order' => $sortOrder++,
                ]);
            }

            if ($line->globalDiscountShare > 0) {
                SaleDiscount::query()->create([
                    'tenant_id' => $sale->tenant_id,
                    'sale_id' => $sale->id,
                    'sale_item_id' => $saleItems[$line->lineId]->id ?? null,
                    'discount_type' => SaleDiscountType::Global,
                    'source' => SaleDiscountSource::Manual,
                    'label' => 'Global discount share',
                    'amount' => $line->globalDiscountShare,
                    'sort_order' => $sortOrder++,
                ]);
            }
        }
    }

    private function createSalePayments(Sale $sale, PaymentResult $paymentResult): void
    {
        foreach ($paymentResult->lines as $index => $line) {
            SalePayment::query()->create([
                'tenant_id' => $sale->tenant_id,
                'sale_id' => $sale->id,
                'payment_transaction_id' => $line->transaction->id,
                'payment_method' => (is_array($line->transaction->metadata) ? ($line->transaction->metadata['method_code'] ?? null) : null)
                    ?: $line->transaction->payment_method->value,
                'amount' => $line->transaction->amount,
                'currency' => $line->transaction->currency,
                'sort_order' => $index,
            ]);
        }
    }

    /**
     * Receipt then SyncEvent, still inside the sale transaction.
     * The domain event fires only after commit so a listener cannot undo the sale.
     *
     * @return array{receipt: SaleReceipt, sync_event: SyncEvent, payload: array<string, mixed>}
     */
    /**
     * @param  array<string, mixed>  $payload
     * @return array{earned: int, redeemed: int, points: int, reward_per_point: int, spend_per_point: int}
     */
    private function applyCustomerLoyalty(Sale $sale, array $payload, User $user): array
    {
        $empty = [
            'earned' => 0,
            'redeemed' => 0,
            'points' => 0,
            'reward_per_point' => $this->loyalty->rewardAmount(1),
            'spend_per_point' => max(1, (int) config('customers.loyalty_points_per_amount', 100000)),
        ];

        if ($sale->customer_id === null) {
            return $empty;
        }

        $customer = Customer::query()->whereKey($sale->customer_id)->lockForUpdate()->first();
        if ($customer === null) {
            return $empty;
        }

        $redeemed = $this->loyalty->redeemOnSale(
            $customer,
            $sale,
            (int) ($payload['loyalty_points'] ?? 0),
            $payload['global_discount'] ?? null,
            $user->id,
        );
        $earned = $this->loyalty->earnOnSale($customer, $sale, $user->id);
        $customer->refresh();

        return [
            'earned' => $earned,
            'redeemed' => $redeemed,
            'points' => (int) $customer->loyalty_points,
            'reward_per_point' => $this->loyalty->rewardAmount(1),
            'spend_per_point' => max(1, (int) config('customers.loyalty_points_per_amount', 100000)),
        ];
    }

    private function sealCompletedSale(Sale $sale, User $user, ?string $deviceId): array
    {
        $format = SaleDocumentFormat::Thermal80;
        $receipt = $this->receipts->issue(
            sale: $sale,
            format: $format,
            printedBy: $user,
            deviceId: $deviceId,
        );
        $event = SyncEvent::recordCompletedSale($sale, $receipt);
        $payload = $this->receiptPayloads->build($sale, $format, $receipt);

        $saleId = $sale->id;
        DB::afterCommit(function () use ($saleId): void {
            $fresh = Sale::query()->find($saleId);
            if ($fresh !== null) {
                SaleCompleted::dispatch($fresh);
            }
        });

        return [
            'receipt' => $receipt,
            'sync_event' => $event,
            'payload' => $payload,
        ];
    }

    private function decreaseInventory(
        Sale $sale,
        Warehouse $warehouse,
        CartCalculationResult $cart,
        User $user,
    ): void {
        foreach ($cart->lines as $line) {
            if ($line->productId === null) {
                continue;
            }

            $product = Product::query()->find($line->productId);

            if ($product === null || ! $product->requiresStock()) {
                continue;
            }

            $volumeMl = $line->volumeMl && $line->volumeMl > 0 ? $line->volumeMl : null;
            $unitCost = $volumeMl && (int) $product->bottle_volume_ml > 0
                ? intdiv((int) $product->cost_price, (int) $product->bottle_volume_ml)
                : $product->cost_price;

            $this->movementService->record([
                'warehouse' => $warehouse,
                'product' => $product,
                'movement_type' => InventoryMovementType::Sale,
                'quantity' => $line->stockQuantity(),
                'product_variant_id' => $line->productVariantId,
                'unit_cost' => $unitCost,
                'reference' => $sale,
                'performed_by' => $user->id,
                'notes' => "Sale {$sale->reference}",
            ]);
        }
    }

    private function assertPending(Sale $sale): void
    {
        if ($sale->status !== SaleStatus::Pending) {
            throw ValidationException::withMessages([
                'status' => ['Seules les commandes en attente peuvent être modifiées.'],
            ]);
        }
    }

    /** @param  array<string, mixed>  $payload */
    private function writePendingSale(Store $store, array $payload, User $user): Sale
    {
        $this->validateProducts($store, $payload);
        $cart = $this->cartEngine->calculateForStore($store, $payload);
        $warehouse = $this->resolveWarehouse($store, $payload['warehouse_id'] ?? null);

        $sale = Sale::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'customer_id' => $payload['customer_id'] ?? null,
            'warehouse_id' => $warehouse->id,
            'cash_register_id' => $payload['cash_register_id'] ?? null,
            'cashier_shift_id' => $payload['cashier_shift_id'] ?? null,
            'device_id' => $payload['device_id'] ?? null,
            'processed_by' => $user->id,
            'reference' => $this->nextReference($store->tenant_id),
            'status' => SaleStatus::Pending,
            'subtotal' => $cart->subtotal,
            'tax_total' => $cart->taxTotal,
            'discount_total' => $cart->discountTotal,
            'fees_total' => $cart->feesTotal,
            'total' => $cart->grandTotal,
            'paid_amount' => 0,
            'payment_status' => SalePaymentStatus::Unpaid,
            'currency' => $cart->currency,
            'idempotency_key' => $payload['idempotency_key'] ?? null,
            'completed_at' => null,
            'notes' => $payload['notes'] ?? null,
        ]);

        $saleItems = $this->createSaleItems($sale, $cart);
        $this->createSaleTaxes($sale, $saleItems, $cart);
        $this->createSaleDiscounts($sale, $saleItems, $cart);

        return $sale;
    }

    /** @param  array<string, mixed>  $payload */
    private function replacePendingContents(Sale $sale, Store $store, array $payload): void
    {
        $this->validateProducts($store, $payload);
        $cart = $this->cartEngine->calculateForStore($store, $payload);
        $warehouse = $this->resolveWarehouse($store, $payload['warehouse_id'] ?? $sale->warehouse_id);

        $this->clearSaleLines($sale);

        $sale->update([
            'customer_id' => $payload['customer_id'] ?? null,
            'warehouse_id' => $warehouse->id,
            'cash_register_id' => $payload['cash_register_id'] ?? $sale->cash_register_id,
            'notes' => $payload['notes'] ?? null,
            'subtotal' => $cart->subtotal,
            'tax_total' => $cart->taxTotal,
            'discount_total' => $cart->discountTotal,
            'fees_total' => $cart->feesTotal,
            'total' => $cart->grandTotal,
            'currency' => $cart->currency,
            'paid_amount' => 0,
            'payment_status' => SalePaymentStatus::Unpaid,
            'status' => SaleStatus::Pending,
            'completed_at' => null,
        ]);

        $saleItems = $this->createSaleItems($sale, $cart);
        $this->createSaleTaxes($sale, $saleItems, $cart);
        $this->createSaleDiscounts($sale, $saleItems, $cart);
    }

    private function clearSaleLines(Sale $sale): void
    {
        $sale->discounts()->delete();
        $sale->taxes()->delete();
        $sale->items()->delete();
    }

    private function nextReference(string $tenantId): string
    {
        $prefix = config('sales.reference_prefix', 'SAL');

        // Serialize reference allocation inside the surrounding transaction.
        Sale::query()
            ->where('tenant_id', $tenantId)
            ->lockForUpdate()
            ->orderBy('id')
            ->limit(1)
            ->get(['id']);

        $max = 0;
        Sale::query()
            ->where('tenant_id', $tenantId)
            ->where('reference', 'like', $prefix.'-%')
            ->pluck('reference')
            ->each(function (string $reference) use (&$max): void {
                if (preg_match('/(\d+)$/', $reference, $matches) === 1) {
                    $max = max($max, (int) $matches[1]);
                }
            });

        return $prefix.'-'.str_pad((string) ($max + 1), 6, '0', STR_PAD_LEFT);
    }
}
