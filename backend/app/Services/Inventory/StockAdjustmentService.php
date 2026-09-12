<?php

namespace App\Services\Inventory;

use App\Enums\InventoryMovementType;
use App\Enums\StockAdjustmentStatus;
use App\Models\Product;
use App\Models\StockAdjustment;
use App\Models\StockAdjustmentItem;
use App\Models\User;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class StockAdjustmentService
{
    public function __construct(
        private readonly InventoryMovementService $movementService,
    ) {}

    /**
     * @param  list<array{
     *     product_id: string,
     *     quantity: int,
     *     product_variant_id?: string|null,
     *     batch_id?: string|null,
     *     unit_cost?: int|null,
     *     notes?: string|null,
     * }>  $items
     */
    public function create(
        Warehouse $warehouse,
        InventoryMovementType $movementType,
        array $items,
        ?User $performedBy = null,
        ?string $reason = null,
    ): StockAdjustment {
        if (! in_array($movementType, InventoryMovementType::adjustmentTypes(), true)) {
            throw ValidationException::withMessages([
                'movement_type' => ['Invalid adjustment movement type.'],
            ]);
        }

        if ($items === []) {
            throw ValidationException::withMessages([
                'items' => ['At least one item is required.'],
            ]);
        }

        return DB::transaction(function () use ($warehouse, $movementType, $items, $performedBy, $reason): StockAdjustment {
            $adjustment = StockAdjustment::query()->create([
                'tenant_id' => $warehouse->tenant_id,
                'adjustment_number' => $this->nextAdjustmentNumber($warehouse->tenant_id),
                'warehouse_id' => $warehouse->id,
                'movement_type' => $movementType,
                'status' => StockAdjustmentStatus::Draft,
                'reason' => $reason,
                'performed_by' => $performedBy?->id,
            ]);

            $this->syncItems($adjustment, $items);

            return $adjustment->fresh(['warehouse', 'items.product:id,sku,name']);
        });
    }

    public function confirm(StockAdjustment $adjustment, ?User $confirmedBy = null): StockAdjustment
    {
        if ($adjustment->status !== StockAdjustmentStatus::Draft) {
            throw ValidationException::withMessages([
                'status' => ['Seule une saisie peut être confirmée.'],
            ]);
        }

        if ($adjustment->items()->count() === 0) {
            throw ValidationException::withMessages([
                'items' => ['Ajoutez au moins un article avant de confirmer.'],
            ]);
        }

        $adjustment->update([
            'status' => StockAdjustmentStatus::Approved,
            'confirmed_by' => $confirmedBy?->id,
            'confirmed_at' => now(),
        ]);

        return $adjustment->fresh(['warehouse', 'items.product:id,sku,name']);
    }

    /**
     * @param  list<array{
     *     product_id: string,
     *     quantity: int,
     *     product_variant_id?: string|null,
     *     batch_id?: string|null,
     *     unit_cost?: int|null,
     *     notes?: string|null,
     * }>  $items
     */
    public function complete(StockAdjustment $adjustment, ?User $performedBy = null): StockAdjustment
    {
        if ($adjustment->status !== StockAdjustmentStatus::Approved) {
            throw ValidationException::withMessages([
                'status' => ['Confirmez d’abord la saisie avant la confirmation finale.'],
            ]);
        }

        $adjustment->load(['warehouse', 'items.product']);

        return DB::transaction(function () use ($adjustment, $performedBy): StockAdjustment {
            foreach ($adjustment->items as $item) {
                $product = $item->product ?? Product::query()->findOrFail($item->product_id);
                $product->assertStockable();

                $this->movementService->record([
                    'warehouse' => $adjustment->warehouse,
                    'product' => $product,
                    'movement_type' => $adjustment->movement_type,
                    'quantity' => $item->quantity,
                    'product_variant_id' => $item->product_variant_id,
                    'batch_id' => $item->batch_id,
                    'unit_cost' => $item->unit_cost,
                    'reference' => $adjustment,
                    'performed_by' => $performedBy?->id ?? $adjustment->performed_by,
                    'notes' => $item->notes,
                ]);
            }

            $adjustment->update([
                'status' => StockAdjustmentStatus::Completed,
                'approved_by' => $performedBy?->id,
                'completed_at' => now(),
            ]);

            return $adjustment->fresh(['warehouse', 'items.product:id,sku,name']);
        });
    }

    /** @param  list<array<string, mixed>>  $items */
    private function syncItems(StockAdjustment $adjustment, array $items): void
    {
        foreach ($items as $item) {
            $product = Product::query()->findOrFail($item['product_id']);
            $product->assertStockable();

            StockAdjustmentItem::query()->create([
                'tenant_id' => $adjustment->tenant_id,
                'stock_adjustment_id' => $adjustment->id,
                'product_id' => $product->id,
                'product_variant_id' => $item['product_variant_id'] ?? null,
                'batch_id' => $item['batch_id'] ?? null,
                'quantity' => $item['quantity'],
                'unit_cost' => $item['unit_cost'] ?? null,
                'notes' => $item['notes'] ?? null,
            ]);
        }
    }

    private function nextAdjustmentNumber(string $tenantId): string
    {
        $count = StockAdjustment::query()
            ->where('tenant_id', $tenantId)
            ->count();

        return 'ADJ-'.str_pad((string) ($count + 1), 6, '0', STR_PAD_LEFT);
    }
}
