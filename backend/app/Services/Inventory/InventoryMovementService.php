<?php

namespace App\Services\Inventory;

use App\Enums\BatchAllocationStrategy;
use App\Enums\InventoryMovementType;
use App\Models\InventoryMovement;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\Warehouse;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class InventoryMovementService
{
    public function __construct(
        private readonly StockBalanceService $stockBalanceService,
        private readonly BatchAllocationService $batchAllocationService,
        private readonly StockAlertService $stockAlertService,
    ) {}

    /**
     * Record a stock movement and update the materialized balance.
     * This is the ONLY entry point for changing stock levels.
     *
     * @param  array{
     *     warehouse: Warehouse,
     *     product: Product,
     *     movement_type: InventoryMovementType,
     *     quantity: int,
     *     product_variant_id?: string|null,
     *     batch_id?: string|null,
     *     serial_number_id?: string|null,
     *     unit_cost?: int|null,
     *     reference?: Model|null,
     *     source_warehouse_id?: string|null,
     *     destination_warehouse_id?: string|null,
     *     performed_by?: string|null,
     *     notes?: string|null,
     *     occurred_at?: \DateTimeInterface|null,
     *     allow_negative?: bool,
     *     auto_allocate?: bool,
     *     allocation_strategy?: BatchAllocationStrategy|null,
     *     allow_expired_batches?: bool,
     * }  $data
     */
    public function record(array $data): InventoryMovement
    {
        $movementType = $data['movement_type'];
        $product = $data['product'];
        $product->assertStockable();
        // Option-style variants share parent stock — never key balances by variant.
        if ($product->isVariantProduct()) {
            $data['product_variant_id'] = null;
        }
        $this->assertWarehouseNotLocked($data['warehouse'], $movementType);
        $autoAllocate = $data['auto_allocate'] ?? true;

        if (
            $movementType->isOutbound()
            && $product->tracksBatches()
            && empty($data['batch_id'])
            && $autoAllocate
        ) {
            $movements = $this->recordWithBatchAllocation($data);

            return $movements[0];
        }

        return $this->recordSingle($data);
    }

    /**
     * @param  list<array{
     *     warehouse: Warehouse,
     *     product: Product,
     *     movement_type: InventoryMovementType,
     *     quantity: int,
     *     product_variant_id?: string|null,
     *     batch_id?: string|null,
     *     serial_number_id?: string|null,
     *     unit_cost?: int|null,
     *     reference?: Model|null,
     *     source_warehouse_id?: string|null,
     *     destination_warehouse_id?: string|null,
     *     performed_by?: string|null,
     *     notes?: string|null,
     *     occurred_at?: \DateTimeInterface|null,
     *     allow_negative?: bool,
     *     auto_allocate?: bool,
     *     allocation_strategy?: BatchAllocationStrategy|null,
     *     allow_expired_batches?: bool,
     * }>  $movements
     * @return list<InventoryMovement>
     */
    public function recordMany(array $movements): array
    {
        return DB::transaction(function () use ($movements): array {
            $recorded = [];

            foreach ($movements as $movementData) {
                $recorded[] = $this->record($movementData);
            }

            return $recorded;
        });
    }

    /**
     * Outbound with FIFO/FEFO batch splitting.
     *
     * @param  array<string, mixed>  $data
     * @return list<InventoryMovement>
     */
    public function recordWithBatchAllocation(array $data): array
    {
        $quantity = $data['quantity'];

        if ($quantity <= 0) {
            throw ValidationException::withMessages([
                'quantity' => ['Quantity must be greater than zero.'],
            ]);
        }

        $allocations = $this->batchAllocationService->allocate(
            warehouse: $data['warehouse'],
            product: $data['product'],
            quantity: $quantity,
            productVariantId: $data['product_variant_id'] ?? null,
            strategy: $data['allocation_strategy'] ?? null,
            allowExpired: $data['allow_expired_batches'] ?? false,
        );

        return DB::transaction(function () use ($data, $allocations): array {
            $movements = [];

            foreach ($allocations as $allocation) {
                $movements[] = $this->recordSingle([
                    ...$data,
                    'batch_id' => $allocation['batch_id'],
                    'quantity' => $allocation['quantity'],
                    'auto_allocate' => false,
                    'unit_cost' => $data['unit_cost'] ?? $allocation['batch']?->unit_cost,
                ]);
            }

            return $movements;
        });
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function recordSingle(array $data): InventoryMovement
    {
        $quantity = $data['quantity'];

        if ($quantity <= 0) {
            throw ValidationException::withMessages([
                'quantity' => ['Quantity must be greater than zero.'],
            ]);
        }

        $movementType = $data['movement_type'];

        if ($movementType->isOutbound() && ! ($data['allow_negative'] ?? false)) {
            $available = $this->stockBalanceService->availableQuantity(
                warehouse: $data['warehouse'],
                product: $data['product'],
                productVariantId: $data['product_variant_id'] ?? null,
                batchId: $data['batch_id'] ?? null,
            );

            if ($available < $quantity) {
                throw ValidationException::withMessages([
                    'quantity' => ["Insufficient stock. Available: {$available}, requested: {$quantity}."],
                ]);
            }

            if (
                ! empty($data['batch_id'])
                && config('inventory.block_expired_batch_outbound', true)
                && ! ($data['allow_expired_batches'] ?? false)
            ) {
                $batch = \App\Models\Batch::query()->find($data['batch_id']);

                if ($batch?->isExpired()) {
                    throw ValidationException::withMessages([
                        'batch_id' => ['Cannot issue stock from an expired batch.'],
                    ]);
                }
            }
        }

        return DB::transaction(function () use ($data, $movementType): InventoryMovement {
            $reference = $data['reference'] ?? null;
            $signedQuantity = $movementType->signedQuantity($data['quantity']);

            $movement = InventoryMovement::query()->create([
                'tenant_id' => $data['warehouse']->tenant_id,
                'warehouse_id' => $data['warehouse']->id,
                'product_id' => $data['product']->id,
                'product_variant_id' => $data['product_variant_id'] ?? null,
                'batch_id' => $data['batch_id'] ?? null,
                'serial_number_id' => $data['serial_number_id'] ?? null,
                'movement_type' => $movementType,
                'quantity' => $signedQuantity,
                'unit_cost' => $data['unit_cost'] ?? null,
                'reference_type' => $reference?->getMorphClass(),
                'reference_id' => $reference?->getKey(),
                'source_warehouse_id' => $data['source_warehouse_id'] ?? null,
                'destination_warehouse_id' => $data['destination_warehouse_id'] ?? null,
                'performed_by' => $data['performed_by'] ?? null,
                'notes' => $data['notes'] ?? null,
                'occurred_at' => $data['occurred_at'] ?? now(),
            ]);

            $this->stockBalanceService->applyMovement($movement);
            $this->stockAlertService->evaluateAfterMovement($movement);

            return $movement;
        });
    }

    private function assertWarehouseNotLocked(Warehouse $warehouse, InventoryMovementType $movementType): void
    {
        $blocked = [
            InventoryMovementType::Sale,
            InventoryMovementType::Purchase,
            InventoryMovementType::PurchaseReturn,
            InventoryMovementType::TransferIn,
            InventoryMovementType::TransferOut,
        ];

        if (! in_array($movementType, $blocked, true)) {
            return;
        }

        if (FullPhysicalCountService::warehouseIsLocked($warehouse->id)) {
            throw ValidationException::withMessages([
                'stock' => ['Un comptage complet est en cours sur cet entrepôt. Les ventes, achats et transferts sont bloqués jusqu’à la clôture.'],
            ]);
        }
    }
}
