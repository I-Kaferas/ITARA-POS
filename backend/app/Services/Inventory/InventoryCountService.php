<?php

namespace App\Services\Inventory;

use App\Enums\InventoryCountStatus;
use App\Enums\InventoryMovementType;
use App\Models\InventoryCount;
use App\Models\InventoryCountItem;
use App\Models\InventoryMovement;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\User;
use App\Models\Warehouse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class InventoryCountService
{
    public function __construct(
        private readonly InventoryMovementService $movementService,
        private readonly StockBalanceService $stockBalanceService,
        private readonly OpeningStockService $openingStock,
    ) {}

    /**
     * @param  list<array{product_id: string, quantity: int, sale_unit_id?: string|null, unit_cost?: int|null}>  $items
     * @return array{count: InventoryCount, lines: list<array<string, mixed>>}
     */
    public function open(
        Warehouse $warehouse,
        array $items,
        ?User $performedBy = null,
        ?string $notes = null,
        ?string $countedAt = null,
    ): array {
        if ($items === []) {
            throw ValidationException::withMessages([
                'items' => ['Ajoutez au moins un article.'],
            ]);
        }

        return DB::transaction(function () use ($warehouse, $items, $performedBy, $notes, $countedAt): array {
            $normalized = [];
            foreach ($items as $item) {
                $product = Product::query()->with(['category:id,name', 'saleUnits', 'unitModel'])->findOrFail($item['product_id']);
                $product->assertStockable();
                $this->assertOpeningAllowed($warehouse, $product);

                $quantity = (int) $item['quantity'];
                if ($quantity < 1) {
                    throw ValidationException::withMessages([
                        'items' => ["La quantité d'ouverture de {$product->name} doit être supérieure ou égale à 1."],
                    ]);
                }

                $resolved = $this->openingStock->resolveLine(
                    $product,
                    $quantity,
                    $item['sale_unit_id'] ?? null,
                    (int) ($item['unit_cost'] ?? 0),
                );
                $normalized[] = ['product' => $product, 'resolved' => $resolved];
            }

            $count = InventoryCount::query()->create([
                'tenant_id' => $warehouse->tenant_id,
                'count_number' => $this->nextNumber($warehouse->tenant_id),
                'warehouse_id' => $warehouse->id,
                'count_type' => 'opening',
                'counted_at' => $countedAt,
                'status' => InventoryCountStatus::Completed,
                'notes' => $notes,
                'performed_by' => $performedBy?->id,
                'confirmed_by' => $performedBy?->id,
                'confirmed_at' => now(),
                'approved_by' => $performedBy?->id,
                'completed_at' => now(),
            ]);

            $lines = [];
            foreach ($normalized as $row) {
                $product = $row['product'];
                $resolved = $row['resolved'];
                InventoryCountItem::query()->create([
                    'tenant_id' => $count->tenant_id,
                    'inventory_count_id' => $count->id,
                    'product_id' => $product->id,
                    'sale_unit_id' => $resolved['sale_unit_id'],
                    'counted_quantity' => $resolved['base_quantity'],
                    'entered_quantity' => $resolved['entered_quantity'],
                    'unit_name' => $resolved['unit_name'],
                    'unit_volume_ml' => $resolved['unit_volume_ml'],
                    'unit_cost' => $resolved['unit_cost'],
                    'line_value' => $resolved['line_value'],
                    'system_quantity' => 0,
                ]);

                $this->movementService->record([
                    'warehouse' => $warehouse,
                    'product' => $product,
                    'movement_type' => InventoryMovementType::InitialStock,
                    'quantity' => $resolved['base_quantity'],
                    'unit_cost' => $resolved['base_unit_cost'],
                    'reference' => $count,
                    'performed_by' => $performedBy?->id,
                    'notes' => "Solde d'ouverture {$count->count_number}",
                    'occurred_at' => $countedAt ? \Illuminate\Support\Carbon::parse($countedAt) : now(),
                ]);

                if ((int) $product->cost_price <= 0 && $resolved['unit_cost'] > 0 && $resolved['sale_unit_id']) {
                    $base = $product->saleUnits->firstWhere('is_base', true);
                    if ($base && $resolved['sale_unit_id'] === $base->id) {
                        $product->update(['cost_price' => $resolved['unit_cost']]);
                    }
                }

                $display = $this->openingStock->describe($product, $resolved['base_quantity']);
                $lines[] = [
                    'product_id' => $product->id,
                    'name' => $product->name,
                    'category' => $product->category?->name,
                    'unit_name' => $resolved['unit_name'],
                    'entered_quantity' => $resolved['entered_quantity'],
                    'unit_volume_ml' => $resolved['unit_volume_ml'],
                    'base_quantity' => $resolved['base_quantity'],
                    'unit_cost' => $resolved['unit_cost'],
                    'line_value' => $resolved['line_value'],
                    'display' => $display['display'],
                    'base_unit' => $display['base_unit'],
                    'performed_by' => $performedBy?->name,
                ];
            }

            return [
                'count' => $count->fresh(['warehouse', 'items.product:id,sku,name', 'performedBy:id,name']),
                'lines' => $lines,
            ];
        });
    }

    /**
     * @param  list<array{product_id: string, quantity: int, product_variant_id?: string|null}>  $items
     */
    public function create(
        Warehouse $warehouse,
        array $items,
        ?User $performedBy = null,
        ?string $notes = null,
        string $countType = 'full',
        ?string $countedAt = null,
    ): InventoryCount
    {
        if ($items === []) {
            throw ValidationException::withMessages([
                'items' => ['Ajoutez au moins un article.'],
            ]);
        }

        return DB::transaction(function () use ($warehouse, $items, $performedBy, $notes, $countType, $countedAt): InventoryCount {
            $count = InventoryCount::query()->create([
                'tenant_id' => $warehouse->tenant_id,
                'count_number' => $this->nextNumber($warehouse->tenant_id),
                'warehouse_id' => $warehouse->id,
                'count_type' => $countType,
                'counted_at' => $countedAt,
                'status' => InventoryCountStatus::Draft,
                'notes' => $notes,
                'performed_by' => $performedBy?->id,
            ]);

            $this->syncItems($count, $warehouse, $items);

            return $count->fresh(['warehouse', 'items.product:id,sku,name']);
        });
    }

    /**
     * @param  list<array{product_id: string, quantity: int, product_variant_id?: string|null}>  $items
     */
    public function update(InventoryCount $count, array $items): InventoryCount
    {
        if ($count->status === InventoryCountStatus::Completed) {
            throw ValidationException::withMessages([
                'status' => ['Un inventaire déjà confirmé ne peut plus être modifié.'],
            ]);
        }

        if ($items === []) {
            throw ValidationException::withMessages([
                'items' => ['Ajoutez au moins un article.'],
            ]);
        }

        return DB::transaction(function () use ($count, $items): InventoryCount {
            $count->items()->delete();
            $count->load('warehouse');
            $this->syncItems($count, $count->warehouse, $items);

            if ($count->status === InventoryCountStatus::Confirmed) {
                $count->update([
                    'status' => InventoryCountStatus::Draft,
                    'confirmed_by' => null,
                    'confirmed_at' => null,
                ]);
            }

            return $count->fresh(['warehouse', 'items.product:id,sku,name']);
        });
    }

    public function confirm(InventoryCount $count, ?User $confirmedBy = null): InventoryCount
    {
        if ($count->status !== InventoryCountStatus::Draft) {
            throw ValidationException::withMessages([
                'status' => ['Seule une saisie peut être confirmée.'],
            ]);
        }

        if ($count->items()->count() === 0) {
            throw ValidationException::withMessages([
                'items' => ['Ajoutez au moins un article avant de confirmer.'],
            ]);
        }

        $count->update([
            'status' => InventoryCountStatus::Confirmed,
            'confirmed_by' => $confirmedBy?->id,
            'confirmed_at' => now(),
        ]);

        return $count->fresh(['warehouse', 'items.product:id,sku,name']);
    }

    public function complete(InventoryCount $count, ?User $performedBy = null): InventoryCount
    {
        if ($count->status !== InventoryCountStatus::Confirmed) {
            throw ValidationException::withMessages([
                'status' => ['Confirmez d’abord la saisie avant la confirmation finale.'],
            ]);
        }

        $count->load(['warehouse', 'items.product']);

        return DB::transaction(function () use ($count, $performedBy): InventoryCount {
            foreach ($count->items as $item) {
                $product = $item->product ?? Product::query()->findOrFail($item->product_id);
                $product->assertStockable();

                $onHand = $this->stockBalanceService->quantityOnHand(
                    warehouse: $count->warehouse,
                    product: $product,
                    productVariantId: $item->product_variant_id,
                );

                $item->update(['system_quantity' => $onHand]);
                $delta = $item->counted_quantity - $onHand;

                if ($delta === 0) {
                    continue;
                }

                $movementType = $count->count_type === 'opening'
                    ? InventoryMovementType::InitialStock
                    : ($delta > 0 ? InventoryMovementType::AdjustmentIn : InventoryMovementType::AdjustmentOut);
                $quantity = $count->count_type === 'opening' ? $item->counted_quantity : abs($delta);

                if ($count->count_type === 'opening' && $onHand > 0) {
                    throw ValidationException::withMessages([
                        'items' => ["{$product->name} est déjà en stock dans cet entrepôt."],
                    ]);
                }

                $this->movementService->record([
                    'warehouse' => $count->warehouse,
                    'product' => $product,
                    'movement_type' => $movementType,
                    'quantity' => $quantity,
                    'product_variant_id' => $item->product_variant_id,
                    'reference' => $count,
                    'performed_by' => $performedBy?->id ?? $count->performed_by,
                    'notes' => "Inventaire {$count->count_number}",
                ]);
            }

            $count->update([
                'status' => InventoryCountStatus::Completed,
                'approved_by' => $performedBy?->id,
                'completed_at' => now(),
            ]);

            return $count->fresh(['warehouse', 'items.product:id,sku,name']);
        });
    }

    /** @param  list<array{product_id: string, quantity: int, product_variant_id?: string|null}>  $items */
    private function syncItems(InventoryCount $count, Warehouse $warehouse, array $items): void
    {
        foreach ($items as $item) {
            $product = Product::query()->findOrFail($item['product_id']);
            $product->assertStockable();

            InventoryCountItem::query()->create([
                'tenant_id' => $count->tenant_id,
                'inventory_count_id' => $count->id,
                'product_id' => $product->id,
                'product_variant_id' => $item['product_variant_id'] ?? null,
                'counted_quantity' => $item['quantity'],
                'system_quantity' => $this->stockBalanceService->quantityOnHand(
                    warehouse: $warehouse,
                    product: $product,
                    productVariantId: $item['product_variant_id'] ?? null,
                ),
            ]);
        }
    }

    /** @return list<string> */
    public function openedProductIds(Warehouse $warehouse): array
    {
        $fromCounts = InventoryCountItem::query()
            ->whereIn('inventory_count_id', InventoryCount::query()
                ->where('warehouse_id', $warehouse->id)
                ->where('count_type', 'opening')
                ->select('id'))
            ->pluck('product_id');

        $fromMovements = InventoryMovement::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('movement_type', InventoryMovementType::InitialStock->value)
            ->pluck('product_id');

        $withStock = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('quantity_on_hand', '>', 0)
            ->pluck('product_id');

        return $fromCounts
            ->merge($fromMovements)
            ->merge($withStock)
            ->unique()
            ->filter()
            ->values()
            ->all();
    }

    private function assertOpeningAllowed(Warehouse $warehouse, Product $product): void
    {
        if (in_array($product->id, $this->openedProductIds($warehouse), true)) {
            throw ValidationException::withMessages([
                'items' => ["{$product->name} a déjà un solde d'ouverture dans cet entrepôt. Corrigez le stock par un ajustement."],
            ]);
        }
    }

    private function nextNumber(string $tenantId): string
    {
        $n = InventoryCount::query()->where('tenant_id', $tenantId)->count() + 1;

        return 'INV-'.str_pad((string) $n, 6, '0', STR_PAD_LEFT);
    }
}
