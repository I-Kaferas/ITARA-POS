<?php

namespace App\Services\Inventory;

use App\Enums\InventoryMovementType;
use App\Models\Batch;
use App\Models\Product;
use App\Models\Warehouse;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BatchService
{
    public function __construct(
        private readonly InventoryMovementService $movementService,
        private readonly StockBalanceService $stockBalanceService,
    ) {}

    /**
     * Receive stock into a batch (creates batch if needed + inventory movement).
     *
     * @param  array{
     *     batch_number: string,
     *     quantity: int,
     *     manufactured_at?: string|null,
     *     expires_at?: string|null,
     *     unit_cost?: int|null,
     *     supplier_id?: string|null,
     *     movement_type?: InventoryMovementType,
     *     reference?: Model|null,
     *     performed_by?: string|null,
     *     notes?: string|null,
     *     metadata?: array|null,
     * }  $data
     */
    public function receiveStock(Warehouse $warehouse, Product $product, array $data): Batch
    {
        if (! $product->tracksBatches()) {
            throw ValidationException::withMessages([
                'product' => ['This product does not track batches.'],
            ]);
        }

        if ($data['quantity'] <= 0) {
            throw ValidationException::withMessages([
                'quantity' => ['Quantity must be greater than zero.'],
            ]);
        }

        if ($product->tracksExpiration() && empty($data['expires_at'])) {
            throw ValidationException::withMessages([
                'expires_at' => ['Expiration date is required for perishable products.'],
            ]);
        }

        return DB::transaction(function () use ($warehouse, $product, $data): Batch {
            $batch = Batch::query()->firstOrCreate(
                [
                    'tenant_id' => $product->tenant_id,
                    'product_id' => $product->id,
                    'batch_number' => $data['batch_number'],
                ],
                [
                    'manufactured_at' => $data['manufactured_at'] ?? null,
                    'expires_at' => $data['expires_at'] ?? null,
                    'unit_cost' => $data['unit_cost'] ?? null,
                    'supplier_id' => $data['supplier_id'] ?? null,
                    'received_at' => now(),
                    'metadata' => $data['metadata'] ?? null,
                ],
            );

            if (! $batch->wasRecentlyCreated) {
                $batch->fill(array_filter([
                    'manufactured_at' => $data['manufactured_at'] ?? null,
                    'expires_at' => $data['expires_at'] ?? null,
                    'unit_cost' => $data['unit_cost'] ?? $batch->unit_cost,
                    'supplier_id' => $data['supplier_id'] ?? null,
                ], fn ($v) => $v !== null));
                $batch->save();
            }

            $movementType = $data['movement_type'] ?? InventoryMovementType::Purchase;

            $this->movementService->record([
                'warehouse' => $warehouse,
                'product' => $product,
                'movement_type' => $movementType,
                'quantity' => $data['quantity'],
                'batch_id' => $batch->id,
                'unit_cost' => $data['unit_cost'] ?? $batch->unit_cost,
                'reference' => $data['reference'] ?? null,
                'performed_by' => $data['performed_by'] ?? null,
                'notes' => $data['notes'] ?? null,
            ]);

            return $batch->fresh(['product', 'stockBalances']);
        });
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function listForProduct(Product $product, ?Warehouse $warehouse = null): array
    {
        $batches = Batch::query()
            ->where('product_id', $product->id)
            ->with(['supplier:id,name', 'stockBalances'])
            ->orderByDesc('created_at')
            ->get();

        return $batches->map(function (Batch $batch) use ($warehouse, $product): array {
            $quantity = $warehouse
                ? $batch->quantityInWarehouse($warehouse)
                : $batch->totalQuantityOnHand();

            return [
                'id' => $batch->id,
                'batch_number' => $batch->batch_number,
                'manufactured_at' => $batch->manufactured_at?->toDateString(),
                'expires_at' => $batch->expires_at?->toDateString(),
                'unit_cost' => $batch->unit_cost,
                'quantity_on_hand' => $quantity,
                'supplier_id' => $batch->supplier_id,
                'supplier' => $batch->supplier,
                'is_expired' => $batch->isExpired(),
                'is_expiring_soon' => $batch->isExpiringSoon(),
                'received_at' => $batch->received_at?->toIso8601String(),
                'allocation_strategy' => $product->allocationStrategy()->value,
            ];
        })->all();
    }

    public function show(Batch $batch, ?Warehouse $warehouse = null): array
    {
        $batch->load(['product', 'supplier', 'stockBalances.warehouse']);

        $balances = $batch->stockBalances->map(fn ($b) => [
            'warehouse_id' => $b->warehouse_id,
            'warehouse' => $b->warehouse,
            'quantity_on_hand' => $b->quantity_on_hand,
            'quantity_available' => $b->quantityAvailable(),
        ]);

        return [
            ...$batch->toArray(),
            'manufactured_at' => $batch->manufactured_at?->toDateString(),
            'expires_at' => $batch->expires_at?->toDateString(),
            'quantity_on_hand' => $warehouse
                ? $batch->quantityInWarehouse($warehouse)
                : $batch->totalQuantityOnHand(),
            'is_expired' => $batch->isExpired(),
            'is_expiring_soon' => $batch->isExpiringSoon(),
            'stock_by_warehouse' => $balances,
        ];
    }
}
