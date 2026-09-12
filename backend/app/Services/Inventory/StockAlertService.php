<?php

namespace App\Services\Inventory;

use App\Enums\InventoryAlertStatus;
use App\Enums\InventoryAlertType;
use App\Events\StockLow;
use App\Models\Batch;
use App\Models\InventoryAlert;
use App\Models\InventoryMovement;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;

class StockAlertService
{
    /**
     * Re-evaluate alerts after an inventory movement.
     */
    public function evaluateAfterMovement(InventoryMovement $movement): void
    {
        $movement->loadMissing(['product', 'warehouse', 'batch']);

        if ($movement->warehouse && $movement->product) {
            $this->evaluateProductStock($movement->warehouse, $movement->product);
        }

        if ($movement->batch) {
            $this->evaluateBatchExpiration($movement->batch, $movement->warehouse);
        }
    }

    /**
     * Full scan for a warehouse (scheduled job / manual refresh).
     */
    public function evaluateWarehouse(Warehouse $warehouse): void
    {
        $productIds = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->distinct()
            ->pluck('product_id');

        Product::query()->whereIn('id', $productIds)->each(function (Product $product) use ($warehouse): void {
            $this->evaluateProductStock($warehouse, $product);
        });

        Batch::query()
            ->whereIn('product_id', $productIds)
            ->each(function (Batch $batch) use ($warehouse): void {
                $this->evaluateBatchExpiration($batch, $warehouse);
            });
    }

    public function evaluateProductStock(Warehouse $warehouse, Product $product): void
    {
        $totalAvailable = $this->totalAvailableQuantity($warehouse, $product);
        $threshold = $product->effectiveLowStockThreshold();

        if ($totalAvailable <= 0) {
            $this->upsertAlert(
                tenantId: $warehouse->tenant_id,
                warehouseId: $warehouse->id,
                productId: $product->id,
                batchId: null,
                type: InventoryAlertType::OutOfStock,
                quantity: $totalAvailable,
                threshold: $threshold,
                message: "Product {$product->sku} is out of stock in {$warehouse->name}.",
            );
            $this->resolveAlertType($warehouse, $product, null, InventoryAlertType::LowStock);

            return;
        }

        $this->resolveAlertType($warehouse, $product, null, InventoryAlertType::OutOfStock);

        if ($threshold !== null && $totalAvailable <= $threshold) {
            $this->upsertAlert(
                tenantId: $warehouse->tenant_id,
                warehouseId: $warehouse->id,
                productId: $product->id,
                batchId: null,
                type: InventoryAlertType::LowStock,
                quantity: $totalAvailable,
                threshold: $threshold,
                message: "Product {$product->sku} is low ({$totalAvailable} ≤ {$threshold}) in {$warehouse->name}.",
            );
        } else {
            $this->resolveAlertType($warehouse, $product, null, InventoryAlertType::LowStock);
        }
    }

    public function evaluateBatchExpiration(Batch $batch, ?Warehouse $warehouse = null): void
    {
        $batch->loadMissing('product');

        if (! $batch->product?->tracksExpiration()) {
            return;
        }

        $quantity = $warehouse
            ? $batch->quantityInWarehouse($warehouse)
            : $batch->totalQuantityOnHand();

        if ($quantity <= 0) {
            if ($warehouse) {
                $this->resolveAlertType($warehouse, $batch->product, $batch->id, InventoryAlertType::Expired);
                $this->resolveAlertType($warehouse, $batch->product, $batch->id, InventoryAlertType::ExpiringSoon);
            }

            return;
        }

        $warehouses = $warehouse
            ? collect([$warehouse])
            : Warehouse::query()->where('tenant_id', $batch->tenant_id)->get();

        foreach ($warehouses as $wh) {
            $qty = $batch->quantityInWarehouse($wh);

            if ($qty <= 0) {
                $this->resolveAlertType($wh, $batch->product, $batch->id, InventoryAlertType::Expired);
                $this->resolveAlertType($wh, $batch->product, $batch->id, InventoryAlertType::ExpiringSoon);

                continue;
            }

            if ($batch->isExpired()) {
                $this->upsertAlert(
                    tenantId: $batch->tenant_id,
                    warehouseId: $wh->id,
                    productId: $batch->product_id,
                    batchId: $batch->id,
                    type: InventoryAlertType::Expired,
                    quantity: $qty,
                    threshold: null,
                    message: "Batch {$batch->batch_number} expired on {$batch->expires_at?->toDateString()} ({$qty} units remaining).",
                    expiresAt: $batch->expires_at,
                );
                $this->resolveAlertType($wh, $batch->product, $batch->id, InventoryAlertType::ExpiringSoon);
            } elseif ($batch->isExpiringSoon()) {
                $this->upsertAlert(
                    tenantId: $batch->tenant_id,
                    warehouseId: $wh->id,
                    productId: $batch->product_id,
                    batchId: $batch->id,
                    type: InventoryAlertType::ExpiringSoon,
                    quantity: $qty,
                    threshold: null,
                    message: "Batch {$batch->batch_number} expires on {$batch->expires_at?->toDateString()} ({$qty} units).",
                    expiresAt: $batch->expires_at,
                );
                $this->resolveAlertType($wh, $batch->product, $batch->id, InventoryAlertType::Expired);
            } else {
                $this->resolveAlertType($wh, $batch->product, $batch->id, InventoryAlertType::Expired);
                $this->resolveAlertType($wh, $batch->product, $batch->id, InventoryAlertType::ExpiringSoon);
            }
        }
    }

    public function acknowledge(InventoryAlert $alert, ?string $userId = null): InventoryAlert
    {
        $alert->update([
            'status' => InventoryAlertStatus::Acknowledged,
            'acknowledged_at' => now(),
            'acknowledged_by' => $userId,
        ]);

        return $alert->fresh();
    }

    public function resolve(InventoryAlert $alert): InventoryAlert
    {
        $alert->update([
            'status' => InventoryAlertStatus::Resolved,
            'resolved_at' => now(),
        ]);

        return $alert->fresh();
    }

    private function totalAvailableQuantity(Warehouse $warehouse, Product $product): int
    {
        return (int) StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->get()
            ->sum(fn (StockBalance $b) => $b->quantityAvailable());
    }

    private function upsertAlert(
        string $tenantId,
        ?string $warehouseId,
        string $productId,
        ?string $batchId,
        InventoryAlertType $type,
        int $quantity,
        ?int $threshold,
        string $message,
        ?\DateTimeInterface $expiresAt = null,
    ): void {
        DB::transaction(function () use ($tenantId, $warehouseId, $productId, $batchId, $type, $quantity, $threshold, $message, $expiresAt): void {
            $existing = InventoryAlert::query()
                ->where('tenant_id', $tenantId)
                ->where('warehouse_id', $warehouseId)
                ->where('product_id', $productId)
                ->when($batchId, fn ($q) => $q->where('batch_id', $batchId), fn ($q) => $q->whereNull('batch_id'))
                ->where('alert_type', $type)
                ->whereIn('status', [InventoryAlertStatus::Active, InventoryAlertStatus::Acknowledged])
                ->first();

            if ($existing) {
                $existing->update([
                    'quantity_on_hand' => $quantity,
                    'threshold_value' => $threshold,
                    'expires_at' => $expiresAt,
                    'message' => $message,
                    'status' => InventoryAlertStatus::Active,
                    'resolved_at' => null,
                ]);

                return;
            }

            $alert = InventoryAlert::query()->create([
                'tenant_id' => $tenantId,
                'warehouse_id' => $warehouseId,
                'product_id' => $productId,
                'batch_id' => $batchId,
                'alert_type' => $type,
                'status' => InventoryAlertStatus::Active,
                'quantity_on_hand' => $quantity,
                'threshold_value' => $threshold,
                'expires_at' => $expiresAt,
                'message' => $message,
            ]);

            if (in_array($type, [InventoryAlertType::LowStock, InventoryAlertType::OutOfStock], true)) {
                StockLow::dispatch($alert);
            }
        });
    }

    private function resolveAlertType(
        Warehouse $warehouse,
        Product $product,
        ?string $batchId,
        InventoryAlertType $type,
    ): void {
        InventoryAlert::query()
            ->where('tenant_id', $warehouse->tenant_id)
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->when($batchId, fn ($q) => $q->where('batch_id', $batchId), fn ($q) => $q->whereNull('batch_id'))
            ->where('alert_type', $type)
            ->whereIn('status', [InventoryAlertStatus::Active, InventoryAlertStatus::Acknowledged])
            ->update([
                'status' => InventoryAlertStatus::Resolved,
                'resolved_at' => now(),
            ]);
    }
}
