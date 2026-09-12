<?php

namespace App\Services\Inventory;

use App\Enums\BatchAllocationStrategy;
use App\Models\Batch;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\Warehouse;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class BatchAllocationService
{
    /**
     * Allocate quantity across batches using FIFO or FEFO.
     *
     * @return list<array{batch_id: string, quantity: int, batch: Batch}>
     */
    public function allocate(
        Warehouse $warehouse,
        Product $product,
        int $quantity,
        ?string $productVariantId = null,
        ?BatchAllocationStrategy $strategy = null,
        bool $allowExpired = false,
    ): array {
        if ($quantity <= 0) {
            throw ValidationException::withMessages([
                'quantity' => ['Quantity must be greater than zero.'],
            ]);
        }

        if (! $product->tracksBatches()) {
            return [['batch_id' => null, 'quantity' => $quantity, 'batch' => null]];
        }

        $strategy ??= $product->allocationStrategy();
        $eligible = $this->eligibleBalances($warehouse, $product, $productVariantId, $allowExpired);
        $sorted = $this->sortBalances($eligible, $strategy);

        $allocations = [];
        $remaining = $quantity;

        foreach ($sorted as $balance) {
            if ($remaining <= 0) {
                break;
            }

            $available = max(0, $balance->quantity_on_hand - $balance->quantity_reserved);

            if ($available <= 0) {
                continue;
            }

            $take = min($available, $remaining);
            $allocations[] = [
                'batch_id' => $balance->batch_id,
                'quantity' => $take,
                'batch' => $balance->batch,
            ];
            $remaining -= $take;
        }

        if ($remaining > 0) {
            throw ValidationException::withMessages([
                'quantity' => ["Insufficient batch stock. Short by {$remaining} units."],
            ]);
        }

        return $allocations;
    }

    /**
     * Preview allocation without recording movements.
     *
     * @return list<array{batch_id: string|null, batch_number: string|null, quantity: int, expires_at: string|null, manufactured_at: string|null}>
     */
    public function preview(
        Warehouse $warehouse,
        Product $product,
        int $quantity,
        ?string $productVariantId = null,
        ?BatchAllocationStrategy $strategy = null,
    ): array {
        $allocations = $this->allocate(
            warehouse: $warehouse,
            product: $product,
            quantity: $quantity,
            productVariantId: $productVariantId,
            strategy: $strategy,
            allowExpired: false,
        );

        return array_map(fn (array $row) => [
            'batch_id' => $row['batch_id'],
            'batch_number' => $row['batch']?->batch_number,
            'quantity' => $row['quantity'],
            'expires_at' => $row['batch']?->expires_at?->toDateString(),
            'manufactured_at' => $row['batch']?->manufactured_at?->toDateString(),
            'unit_cost' => $row['batch']?->unit_cost,
        ], $allocations);
    }

    /**
     * @return Collection<int, StockBalance>
     */
    private function eligibleBalances(
        Warehouse $warehouse,
        Product $product,
        ?string $productVariantId,
        bool $allowExpired,
    ): Collection {
        $blockExpired = config('inventory.block_expired_batch_outbound', true) && ! $allowExpired;

        return StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->whereNotNull('batch_id')
            ->when(
                $productVariantId,
                fn ($q) => $q->where('product_variant_id', $productVariantId),
                fn ($q) => $q->whereNull('product_variant_id'),
            )
            ->where('quantity_on_hand', '>', 0)
            ->with('batch')
            ->get()
            ->filter(function (StockBalance $balance) use ($blockExpired): bool {
                if (! $blockExpired) {
                    return true;
                }

                return ! $balance->batch?->isExpired();
            })
            ->values();
    }

    /**
     * @param  Collection<int, StockBalance>  $balances
     * @return list<StockBalance>
     */
    private function sortBalances(Collection $balances, BatchAllocationStrategy $strategy): array
    {
        $sorted = $balances->all();

        usort($sorted, function (StockBalance $a, StockBalance $b) use ($strategy): int {
            $batchA = $a->batch;
            $batchB = $b->batch;

            if ($strategy === BatchAllocationStrategy::Fefo) {
                $expA = $batchA?->expires_at?->timestamp ?? PHP_INT_MAX;
                $expB = $batchB?->expires_at?->timestamp ?? PHP_INT_MAX;

                if ($expA !== $expB) {
                    return $expA <=> $expB;
                }
            }

            $mfgA = $batchA?->manufactured_at?->timestamp ?? $batchA?->received_at?->timestamp ?? $batchA?->created_at?->timestamp ?? 0;
            $mfgB = $batchB?->manufactured_at?->timestamp ?? $batchB?->received_at?->timestamp ?? $batchB?->created_at?->timestamp ?? 0;

            if ($mfgA !== $mfgB) {
                return $mfgA <=> $mfgB;
            }

            return ($batchA?->batch_number ?? '') <=> ($batchB?->batch_number ?? '');
        });

        return $sorted;
    }
}
