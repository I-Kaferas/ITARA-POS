<?php

namespace App\Services\Sync;

use App\Enums\InventoryMovementType;
use App\Models\Product;
use App\Models\Store;
use App\Models\SyncEvent;
use App\Models\Warehouse;
use App\Services\Inventory\InventoryMovementService;
use App\Services\Inventory\StockBalanceService;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Applies POS outbox stock operations as inventory deltas (never absolute overwrite).
 * Idempotent on movement UUID (entity_id / idempotency_key).
 */
class PosStockPushService
{
    public function __construct(
        private readonly InventoryMovementService $movements,
        private readonly StockBalanceService $balances,
    ) {}

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    public function apply(Store $store, array $operation, array $payload, string $entityId): array
    {
        $uuid = trim((string) ($payload['idempotency_key'] ?? $entityId));
        if ($uuid === '') {
            return [
                'id' => $operation['id'] ?? null,
                'entity_id' => $entityId,
                'status' => 'failed',
                'error' => 'Stock movement UUID required.',
            ];
        }

        $existing = SyncEvent::query()
            ->where('store_id', $store->id)
            ->where('entity_type', 'stock')
            ->where('entity_id', $uuid)
            ->where('event_type', 'stock.updated')
            ->first();

        if ($existing !== null) {
            return [
                'id' => $operation['id'] ?? null,
                'entity_id' => $entityId,
                'status' => 'synced',
                'server_id' => $existing->id,
                'already_processed' => true,
            ];
        }

        $productId = (string) ($payload['product_id'] ?? '');
        if ($productId === '') {
            return [
                'id' => $operation['id'] ?? null,
                'entity_id' => $entityId,
                'status' => 'failed',
                'error' => 'product_id required.',
            ];
        }

        $delta = (int) ($payload['quantity'] ?? $payload['delta'] ?? 0);
        if ($delta === 0) {
            // No-op still recorded for idempotency.
            return $this->recordEventOnly($store, $operation, $payload, $uuid, $entityId);
        }

        try {
            return DB::transaction(function () use ($store, $operation, $payload, $entityId, $uuid, $productId, $delta): array {
                $warehouse = $this->resolveWarehouse($store, $payload['warehouse_id'] ?? null);
                $product = Product::query()
                    ->whereKey($productId)
                    ->where('tenant_id', $store->tenant_id)
                    ->first();

                if ($product === null) {
                    return [
                        'id' => $operation['id'] ?? null,
                        'entity_id' => $entityId,
                        'status' => 'failed',
                        'error' => 'Product not found.',
                    ];
                }

                $movementType = $this->resolveMovementType((string) ($payload['type'] ?? 'ADJUSTMENT'), $delta);
                $absolute = abs($delta);
                $occurredAt = $this->parseOccurredAt($payload['occurred_at'] ?? $payload['created_at'] ?? null);

                // Prefer applying with the existing ledger rule (no negative balances).
                // If it would go negative, report conflict for this op only — batch continues.
                try {
                    $movement = $this->movements->record([
                        'warehouse' => $warehouse,
                        'product' => $product,
                        'movement_type' => $movementType,
                        'quantity' => $absolute,
                        'allow_negative' => false,
                        'auto_allocate' => false,
                        'notes' => 'pos_sync:'.$uuid,
                        'performed_by' => null,
                        'occurred_at' => $occurredAt,
                    ]);
                } catch (ValidationException $stockException) {
                    return [
                        'id' => $operation['id'] ?? null,
                        'entity_id' => $entityId,
                        'status' => 'conflict',
                        'error' => collect($stockException->errors())->flatten()->first()
                            ?? $stockException->getMessage(),
                        'conflict_code' => 'negative_stock',
                    ];
                }

                $onHand = $this->balances->quantityOnHand($warehouse, $product);
                $event = SyncEvent::query()->create([
                    'tenant_id' => $store->tenant_id,
                    'store_id' => $store->id,
                    'device_id' => null,
                    'sequence' => SyncEvent::allocateSequence((string) $store->tenant_id),
                    'event_type' => 'stock.updated',
                    'entity_type' => 'stock',
                    'entity_id' => $uuid,
                    'payload' => [
                        ...$payload,
                        'idempotency_key' => $uuid,
                        'delta' => $delta,
                        'movement_id' => $movement->id,
                        'quantity_on_hand' => $onHand,
                        'warehouse_id' => $warehouse->id,
                        'pos_id' => $payload['pos_id'] ?? $payload['device_id'] ?? null,
                    ],
                    'occurred_at' => $occurredAt,
                ]);

                return [
                    'id' => $operation['id'] ?? null,
                    'entity_id' => $entityId,
                    'status' => 'synced',
                    'server_id' => $event->id,
                    'stock' => [[
                        'product_id' => $product->id,
                        'quantity_on_hand' => $onHand,
                        'stock_version' => (int) ($event->sequence),
                    ]],
                ];
            });
        } catch (ValidationException $exception) {
            return [
                'id' => $operation['id'] ?? null,
                'entity_id' => $entityId,
                'status' => 'conflict',
                'error' => collect($exception->errors())->flatten()->first() ?? $exception->getMessage(),
                'conflict_code' => 'stock_validation',
            ];
        } catch (\Throwable $exception) {
            report($exception);

            return [
                'id' => $operation['id'] ?? null,
                'entity_id' => $entityId,
                'status' => 'failed',
                'error' => 'Stock sync failed.',
            ];
        }
    }

    /**
     * @param  array<string, mixed>  $operation
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function recordEventOnly(
        Store $store,
        array $operation,
        array $payload,
        string $uuid,
        string $entityId,
    ): array {
        $event = SyncEvent::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'device_id' => null,
            'sequence' => SyncEvent::allocateSequence((string) $store->tenant_id),
            'event_type' => 'stock.updated',
            'entity_type' => 'stock',
            'entity_id' => $uuid,
            'payload' => [...$payload, 'idempotency_key' => $uuid, 'delta' => 0],
            'occurred_at' => $this->parseOccurredAt($payload['occurred_at'] ?? null),
        ]);

        return [
            'id' => $operation['id'] ?? null,
            'entity_id' => $entityId,
            'status' => 'synced',
            'server_id' => $event->id,
            'already_processed' => false,
        ];
    }

    private function resolveWarehouse(Store $store, mixed $warehouseId): Warehouse
    {
        $store->loadMissing('branch');

        if (is_string($warehouseId) && $warehouseId !== '') {
            $warehouse = Warehouse::query()
                ->where('branch_id', $store->branch_id)
                ->where('is_active', true)
                ->find($warehouseId);

            if ($warehouse !== null) {
                return $warehouse;
            }
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

    private function resolveMovementType(string $rawType, int $delta): InventoryMovementType
    {
        $normalized = strtoupper(trim($rawType));

        return match ($normalized) {
            'SALE' => InventoryMovementType::Sale,
            'SALE_RETURN', 'RETURN' => InventoryMovementType::SaleReturn,
            'DAMAGE' => InventoryMovementType::Damage,
            'LOSS' => InventoryMovementType::Loss,
            'EXPIRED' => InventoryMovementType::Expired,
            'PRODUCTION_IN', 'ADJUSTMENT_IN' => InventoryMovementType::AdjustmentIn,
            'PRODUCTION_OUT', 'ADJUSTMENT_OUT' => InventoryMovementType::AdjustmentOut,
            'PURCHASE' => InventoryMovementType::Purchase,
            'INITIAL_STOCK', 'OPENING' => InventoryMovementType::InitialStock,
            default => $delta >= 0
                ? InventoryMovementType::AdjustmentIn
                : InventoryMovementType::AdjustmentOut,
        };
    }

    private function parseOccurredAt(mixed $value): Carbon
    {
        if ($value instanceof \DateTimeInterface) {
            return Carbon::instance(\DateTimeImmutable::createFromInterface($value));
        }

        if (is_string($value) && trim($value) !== '') {
            try {
                return Carbon::parse($value);
            } catch (\Throwable) {
            }
        }

        return now();
    }
}
