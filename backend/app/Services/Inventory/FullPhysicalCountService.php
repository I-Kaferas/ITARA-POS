<?php

namespace App\Services\Inventory;

use App\Enums\InventoryCountStatus;
use App\Enums\InventoryMovementType;
use App\Models\InventoryCount;
use App\Models\InventoryCountItem;
use App\Models\Product;
use App\Models\StockBalance;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Audit\AuditLogService;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class FullPhysicalCountService
{
    public const REASONS = [
        'loss',
        'breakage',
        'damaged',
        'theft',
        'entry_error',
        'conversion_error',
        'unrecorded_consumption',
        'found',
        'other',
    ];

    public function __construct(
        private readonly OpeningStockService $openingStock,
        private readonly InventoryMovementService $movementService,
        private readonly AuditLogService $auditLogService,
    ) {}

    /**
     * @return array{count: InventoryCount, summary: array<string, mixed>}
     */
    public function start(
        Warehouse $warehouse,
        User $user,
        ?string $countedAt,
        ?string $zone,
        ?string $categoryId,
        ?string $notes,
        bool $lockMovements,
        ?string $responsibleId,
    ): array {
        return DB::transaction(function () use ($warehouse, $user, $countedAt, $zone, $categoryId, $notes, $lockMovements, $responsibleId): array {
            $count = InventoryCount::query()->create([
                'tenant_id' => $warehouse->tenant_id,
                'count_number' => $this->nextNumber($warehouse->tenant_id),
                'warehouse_id' => $warehouse->id,
                'count_type' => 'full',
                'counted_at' => $countedAt,
                'zone' => $zone,
                'category_id' => $categoryId,
                'lock_movements' => $lockMovements,
                'status' => InventoryCountStatus::InProgress,
                'notes' => $notes,
                'performed_by' => $responsibleId ?: $user->id,
                'started_at' => now(),
            ]);

            $this->snapshotProducts($count, $warehouse, $categoryId);
            $this->auditLogService->log('inventory_count.created', $count, $user->id, [
                'count_number' => $count->count_number,
                'warehouse_id' => $warehouse->id,
                'lock_movements' => $lockMovements,
            ]);

            return $this->present($count->fresh());
        });
    }

    /**
     * @param  list<array{id: string, entered_quantity?: int|null, remainder_ml?: int|null, sale_unit_id?: string|null, variance_reason?: string|null, notes?: string|null}>  $lines
     */
    public function saveLines(InventoryCount $count, array $lines, User $user): array
    {
        $this->assertEditable($count);

        return DB::transaction(function () use ($count, $lines, $user): array {
            if ($count->status === InventoryCountStatus::Draft) {
                $count->update([
                    'status' => InventoryCountStatus::InProgress,
                    'started_at' => $count->started_at ?? now(),
                ]);
            }

            foreach ($lines as $line) {
                $item = InventoryCountItem::query()
                    ->where('inventory_count_id', $count->id)
                    ->where('id', $line['id'])
                    ->first();
                if (! $item) {
                    continue;
                }

                $product = Product::query()->with(['saleUnits', 'unitModel'])->findOrFail($item->product_id);
                $entered = array_key_exists('entered_quantity', $line) ? $line['entered_quantity'] : $item->entered_quantity;
                $remainder = max(0, (int) ($line['remainder_ml'] ?? $item->remainder_ml ?? 0));
                $saleUnitId = $line['sale_unit_id'] ?? $item->sale_unit_id;
                $reason = $line['variance_reason'] ?? $item->variance_reason;
                $notes = $line['notes'] ?? $item->notes;

                $base = null;
                $unitName = $item->unit_name;
                $volume = $item->unit_volume_ml;
                if ($entered !== null) {
                    $resolved = $this->openingStock->resolveLine($product, (int) $entered, $saleUnitId, 0);
                    $base = $resolved['base_quantity'] + ($product->tracksVolume() ? $remainder : 0);
                    $unitName = $resolved['unit_name'];
                    $volume = $resolved['unit_volume_ml'];
                    $saleUnitId = $resolved['sale_unit_id'];
                }

                $previous = $item->counted_quantity;
                $item->update([
                    'entered_quantity' => $entered,
                    'remainder_ml' => $product->tracksVolume() ? $remainder : null,
                    'sale_unit_id' => $saleUnitId,
                    'unit_name' => $unitName,
                    'unit_volume_ml' => $volume,
                    'counted_quantity' => $base ?? $item->counted_quantity,
                    'variance_reason' => $reason,
                    'notes' => $notes,
                ]);

                if ($base !== null && $previous !== $base) {
                    $this->auditLogService->log('inventory_count.quantity_changed', $count, $user->id, [
                        'product_id' => $product->id,
                        'product' => $product->name,
                        'old_quantity' => $previous,
                        'new_quantity' => $base,
                        'reason' => $reason,
                    ]);
                }
            }

            return $this->present($count->fresh());
        });
    }

    public function submit(InventoryCount $count, User $user): array
    {
        $this->assertStatus($count, [InventoryCountStatus::Draft, InventoryCountStatus::InProgress]);
        $this->assertAllCounted($count);

        $count->update([
            'status' => InventoryCountStatus::Counted,
            'submitted_at' => now(),
        ]);
        $this->auditLogService->log('inventory_count.submitted', $count, $user->id, ['status' => 'counted']);

        return $this->present($count->fresh());
    }

    public function review(InventoryCount $count, User $user): array
    {
        $this->assertStatus($count, [InventoryCountStatus::Counted]);
        $count->update([
            'status' => InventoryCountStatus::Review,
            'reviewed_at' => now(),
            'confirmed_by' => $user->id,
            'confirmed_at' => now(),
        ]);
        $this->auditLogService->log('inventory_count.reviewed', $count, $user->id, ['status' => 'review']);

        return $this->present($count->fresh());
    }

    public function approve(InventoryCount $count, User $user): array
    {
        $this->assertStatus($count, [InventoryCountStatus::Review, InventoryCountStatus::Counted]);
        $count->update([
            'status' => InventoryCountStatus::Approved,
            'approved_by' => $user->id,
        ]);
        $this->auditLogService->log('inventory_count.approved', $count, $user->id, ['status' => 'approved']);

        return $this->present($count->fresh());
    }

    public function finalize(InventoryCount $count, User $user): array
    {
        $this->assertStatus($count, [InventoryCountStatus::Approved, InventoryCountStatus::Confirmed]);
        $count->load(['warehouse', 'items.product.saleUnits', 'items.product.unitModel']);

        return DB::transaction(function () use ($count, $user): array {
            foreach ($count->items as $item) {
                $physical = (int) $item->counted_quantity;
                $system = (int) ($item->system_quantity ?? 0);
                $delta = $physical - $system;
                if ($delta === 0 || $item->entered_quantity === null) {
                    continue;
                }

                $product = $item->product ?? Product::query()->findOrFail($item->product_id);
                $product->assertStockable();
                $type = $delta > 0
                    ? InventoryMovementType::InventoryAdjustmentIn
                    : InventoryMovementType::InventoryAdjustmentOut;

                $this->movementService->record([
                    'warehouse' => $count->warehouse,
                    'product' => $product,
                    'movement_type' => $type,
                    'quantity' => abs($delta),
                    'unit_cost' => $this->unitCost($product),
                    'reference' => $count,
                    'performed_by' => $user->id,
                    'notes' => trim("Inventaire {$count->count_number} · ".($item->variance_reason ?: 'ajustement').($item->notes ? ' · '.$item->notes : '')),
                    'occurred_at' => $count->counted_at ?? now(),
                ]);
            }

            $count->update([
                'status' => InventoryCountStatus::Completed,
                'lock_movements' => false,
                'completed_at' => now(),
                'approved_by' => $count->approved_by ?: $user->id,
            ]);
            $this->auditLogService->log('inventory_count.completed', $count, $user->id, [
                'status' => 'completed',
                'summary' => $this->summary($count),
            ]);

            return $this->present($count->fresh());
        });
    }

    public function cancel(InventoryCount $count, User $user, ?string $reason = null): array
    {
        if (in_array($count->status, [InventoryCountStatus::Completed, InventoryCountStatus::Cancelled], true)) {
            throw ValidationException::withMessages([
                'status' => ['Cet inventaire ne peut plus être annulé.'],
            ]);
        }

        $count->update([
            'status' => InventoryCountStatus::Cancelled,
            'lock_movements' => false,
            'cancelled_at' => now(),
            'cancelled_by' => $user->id,
            'notes' => trim(($count->notes ? $count->notes."\n" : '').($reason ?: '')),
        ]);
        $this->auditLogService->log('inventory_count.cancelled', $count, $user->id, ['reason' => $reason]);

        return $this->present($count->fresh());
    }

    public function present(InventoryCount $count): array
    {
        $count->load([
            'warehouse:id,name,code',
            'performedBy:id,name',
            'confirmedBy:id,name',
            'approvedBy:id,name',
            'items.product:id,sku,name,unit,bottle_volume_ml,cost_price,category_id',
            'items.product.category:id,name',
            'items.product.saleUnits:id,product_id,name,volume_ml,is_base',
            'items.saleUnit:id,name,volume_ml',
        ]);

        return [
            'count' => $count,
            'summary' => $this->summary($count),
        ];
    }

    public static function warehouseIsLocked(string $warehouseId): bool
    {
        return InventoryCount::query()
            ->where('warehouse_id', $warehouseId)
            ->where('lock_movements', true)
            ->whereIn('status', [
                InventoryCountStatus::Draft->value,
                InventoryCountStatus::InProgress->value,
                InventoryCountStatus::Counted->value,
                InventoryCountStatus::Review->value,
                InventoryCountStatus::Approved->value,
            ])
            ->exists();
    }

    private function snapshotProducts(InventoryCount $count, Warehouse $warehouse, ?string $categoryId): void
    {
        $quantities = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->selectRaw('product_id, SUM(quantity_on_hand) as qty')
            ->groupBy('product_id')
            ->pluck('qty', 'product_id');

        $products = Product::query()
            ->with(['saleUnits', 'unitModel', 'category:id,name'])
            ->where('is_active', true)
            ->whereNotIn('product_type', Product::nonStockableTypes())
            ->when($categoryId, fn ($query) => $query->where('category_id', $categoryId))
            ->orderBy('name')
            ->get();

        foreach ($products as $product) {
            $unit = $this->openingStock->resolveUnit($product, null);
            $system = (int) ($quantities[$product->id] ?? 0);
            InventoryCountItem::query()->create([
                'tenant_id' => $count->tenant_id,
                'inventory_count_id' => $count->id,
                'product_id' => $product->id,
                'sale_unit_id' => $unit['id'],
                'system_quantity' => $system,
                'counted_quantity' => 0,
                'entered_quantity' => null,
                'unit_name' => $unit['name'],
                'unit_volume_ml' => $product->tracksVolume() ? $unit['volume_ml'] : null,
                'remainder_ml' => $product->tracksVolume() ? 0 : null,
            ]);
        }
    }

    /** @return array<string, mixed> */
    private function summary(InventoryCount $count): array
    {
        $count->loadMissing(['items.product']);
        $total = $count->items->count();
        $counted = 0;
        $matched = 0;
        $shortage = 0;
        $surplus = 0;
        $shortageValue = 0;
        $surplusValue = 0;

        foreach ($count->items as $item) {
            if ($item->entered_quantity === null) {
                continue;
            }
            $counted++;
            $delta = (int) $item->counted_quantity - (int) ($item->system_quantity ?? 0);
            $value = abs($delta) * $this->unitCost($item->product);
            if ($delta === 0) {
                $matched++;
            } elseif ($delta < 0) {
                $shortage++;
                $shortageValue += $value;
            } else {
                $surplus++;
                $surplusValue += $value;
            }
        }

        return [
            'total_products' => $total,
            'counted_products' => $counted,
            'matched' => $matched,
            'shortage' => $shortage,
            'surplus' => $surplus,
            'shortage_value' => $shortageValue,
            'surplus_value' => $surplusValue,
            'net_value' => $surplusValue - $shortageValue,
        ];
    }

    private function unitCost(?Product $product): int
    {
        if (! $product) {
            return 0;
        }
        $cost = max(0, (int) $product->cost_price);
        $volume = (int) $product->bottle_volume_ml;
        if ($product->tracksVolume() && $volume > 0) {
            return intdiv($cost, $volume);
        }

        return $cost;
    }

    private function assertEditable(InventoryCount $count): void
    {
        $this->assertStatus($count, [InventoryCountStatus::Draft, InventoryCountStatus::InProgress, InventoryCountStatus::Review]);
    }

    /** @param  list<InventoryCountStatus>  $allowed */
    private function assertStatus(InventoryCount $count, array $allowed): void
    {
        if (! in_array($count->status, $allowed, true)) {
            throw ValidationException::withMessages([
                'status' => ['Cette action n’est pas autorisée pour le statut actuel.'],
            ]);
        }
    }

    private function assertAllCounted(InventoryCount $count): void
    {
        $missing = $count->items()->whereNull('entered_quantity')->count();
        if ($missing > 0) {
            throw ValidationException::withMessages([
                'items' => ["{$missing} produit(s) n’ont pas encore été comptés."],
            ]);
        }
    }

    private function nextNumber(string $tenantId): string
    {
        $year = now()->year;
        $prefix = "INV-{$year}-";
        $last = InventoryCount::query()
            ->where('tenant_id', $tenantId)
            ->where('count_number', 'like', $prefix.'%')
            ->orderByDesc('count_number')
            ->value('count_number');
        $next = 1;
        if (is_string($last) && preg_match('/(\d+)$/', $last, $matches)) {
            $next = ((int) $matches[1]) + 1;
        }

        return $prefix.str_pad((string) $next, 4, '0', STR_PAD_LEFT);
    }
}
