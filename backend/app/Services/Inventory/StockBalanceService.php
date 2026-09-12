<?php

namespace App\Services\Inventory;

use App\Models\InventoryMovement;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;

class StockBalanceService
{
    public function applyMovement(InventoryMovement $movement): StockBalance
    {
        return StockBalanceGuard::runAuthorized(function () use ($movement): StockBalance {
            $balance = $this->findOrCreateBalance(
                tenantId: $movement->tenant_id,
                warehouseId: $movement->warehouse_id,
                productId: $movement->product_id,
                productVariantId: $movement->product_variant_id,
                batchId: $movement->batch_id,
            );

            $balance->quantity_on_hand += $movement->quantity;
            $balance->last_movement_id = $movement->id;
            $balance->save();

            return $balance->fresh();
        });
    }

    public function availableQuantity(
        Warehouse $warehouse,
        Product $product,
        ?string $productVariantId = null,
        ?string $batchId = null,
    ): int {
        $balance = $this->findBalance(
            tenantId: $warehouse->tenant_id,
            warehouseId: $warehouse->id,
            productId: $product->id,
            productVariantId: $productVariantId,
            batchId: $batchId,
        );

        return $balance?->quantityAvailable() ?? 0;
    }

    public function quantityOnHand(
        Warehouse $warehouse,
        Product $product,
        ?string $productVariantId = null,
        ?string $batchId = null,
    ): int {
        $balance = $this->findBalance(
            tenantId: $warehouse->tenant_id,
            warehouseId: $warehouse->id,
            productId: $product->id,
            productVariantId: $productVariantId,
            batchId: $batchId,
        );

        return $balance?->quantity_on_hand ?? 0;
    }

    /**
     * Recompute balance from movements (reconciliation helper).
     */
    public function reconcile(
        Warehouse $warehouse,
        Product $product,
        ?string $productVariantId = null,
        ?string $batchId = null,
    ): StockBalance {
        $sum = (int) InventoryMovement::query()
            ->where('tenant_id', $warehouse->tenant_id)
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->when(
                $productVariantId,
                fn ($q) => $q->where('product_variant_id', $productVariantId),
                fn ($q) => $q->whereNull('product_variant_id'),
            )
            ->when(
                $batchId,
                fn ($q) => $q->where('batch_id', $batchId),
                fn ($q) => $q->whereNull('batch_id'),
            )
            ->sum('quantity');

        return StockBalanceGuard::runAuthorized(function () use ($warehouse, $product, $productVariantId, $batchId, $sum): StockBalance {
            $balance = $this->findOrCreateBalance(
                tenantId: $warehouse->tenant_id,
                warehouseId: $warehouse->id,
                productId: $product->id,
                productVariantId: $productVariantId,
                batchId: $batchId,
            );

            $balance->quantity_on_hand = $sum;
            $balance->save();

            return $balance->fresh();
        });
    }

    private function findBalance(
        string $tenantId,
        string $warehouseId,
        string $productId,
        ?string $productVariantId,
        ?string $batchId,
    ): ?StockBalance {
        return StockBalance::query()
            ->where('tenant_id', $tenantId)
            ->where('warehouse_id', $warehouseId)
            ->where('product_id', $productId)
            ->when(
                $productVariantId,
                fn ($q) => $q->where('product_variant_id', $productVariantId),
                fn ($q) => $q->whereNull('product_variant_id'),
            )
            ->when(
                $batchId,
                fn ($q) => $q->where('batch_id', $batchId),
                fn ($q) => $q->whereNull('batch_id'),
            )
            ->lockForUpdate()
            ->first();
    }

    private function findOrCreateBalance(
        string $tenantId,
        string $warehouseId,
        string $productId,
        ?string $productVariantId,
        ?string $batchId,
    ): StockBalance {
        return DB::transaction(function () use ($tenantId, $warehouseId, $productId, $productVariantId, $batchId): StockBalance {
            $existing = $this->findBalance($tenantId, $warehouseId, $productId, $productVariantId, $batchId);

            if ($existing) {
                return $existing;
            }

            return StockBalance::query()->create([
                'tenant_id' => $tenantId,
                'warehouse_id' => $warehouseId,
                'product_id' => $productId,
                'product_variant_id' => $productVariantId,
                'batch_id' => $batchId,
                'quantity_on_hand' => 0,
                'quantity_reserved' => 0,
            ]);
        });
    }
}
