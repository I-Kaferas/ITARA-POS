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
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CycleCountService
{
    public function __construct(
        private readonly OpeningStockService $openingStock,
        private readonly InventoryMovementService $movementService,
        private readonly AuditLogService $auditLogService,
        private readonly FullPhysicalCountService $fullCountService,
    ) {}

    /**
     * @param  list<string>  $productIds
     * @return array{count: InventoryCount, summary: array<string, mixed>}
     */
    public function plan(
        Warehouse $warehouse,
        User $user,
        ?string $plannedAt,
        ?string $zone,
        ?string $categoryId,
        ?string $inventoryClass,
        array $productIds,
        ?string $notes,
        ?string $responsibleId,
    ): array {
        $products = $this->resolveProducts($warehouse, $productIds, $categoryId, $inventoryClass);
        if ($products->isEmpty()) {
            throw ValidationException::withMessages([
                'items' => ['Sélectionnez au moins un article quantifiable à compter.'],
            ]);
        }

        return DB::transaction(function () use ($warehouse, $user, $plannedAt, $zone, $categoryId, $notes, $responsibleId, $products): array {
            $count = InventoryCount::query()->create([
                'tenant_id' => $warehouse->tenant_id,
                'count_number' => $this->nextNumber($warehouse->tenant_id),
                'warehouse_id' => $warehouse->id,
                'count_type' => 'cycle',
                'counted_at' => $plannedAt,
                'zone' => $zone,
                'category_id' => $categoryId,
                'lock_movements' => false,
                'status' => InventoryCountStatus::Scheduled,
                'notes' => $notes,
                'performed_by' => $responsibleId ?: $user->id,
            ]);

            foreach ($products as $product) {
                $unit = $this->openingStock->resolveUnit($product, null);
                InventoryCountItem::query()->create([
                    'tenant_id' => $count->tenant_id,
                    'inventory_count_id' => $count->id,
                    'product_id' => $product->id,
                    'sale_unit_id' => $unit['id'],
                    'system_quantity' => null,
                    'counted_quantity' => 0,
                    'entered_quantity' => null,
                    'unit_name' => $unit['name'],
                    'unit_volume_ml' => $product->tracksVolume() ? $unit['volume_ml'] : null,
                    'remainder_ml' => $product->tracksVolume() ? 0 : null,
                ]);
            }

            $this->auditLogService->log('cycle_count.planned', $count, $user->id, [
                'count_number' => $count->count_number,
                'products' => $products->count(),
            ]);

            return $this->fullCountService->present($count->fresh());
        });
    }

    public function start(InventoryCount $count, User $user): array
    {
        if ($count->count_type !== 'cycle' || $count->status !== InventoryCountStatus::Scheduled) {
            throw ValidationException::withMessages([
                'status' => ['Seul un comptage cyclique planifié peut être démarré.'],
            ]);
        }

        return DB::transaction(function () use ($count, $user): array {
            $count->load(['warehouse', 'items.product.saleUnits', 'items.product.unitModel']);
            $quantities = StockBalance::query()
                ->where('warehouse_id', $count->warehouse_id)
                ->whereIn('product_id', $count->items->pluck('product_id'))
                ->selectRaw('product_id, SUM(quantity_on_hand) as qty')
                ->groupBy('product_id')
                ->pluck('qty', 'product_id');

            foreach ($count->items as $item) {
                $item->update([
                    'system_quantity' => (int) ($quantities[$item->product_id] ?? 0),
                ]);
            }

            $count->update([
                'status' => InventoryCountStatus::InProgress,
                'started_at' => now(),
                'lock_movements' => false,
            ]);
            $this->auditLogService->log('cycle_count.started', $count, $user->id, ['status' => 'in_progress']);

            return $this->fullCountService->present($count->fresh());
        });
    }

    public function generateDue(Warehouse $warehouse, User $user): array
    {
        $due = $this->suggest($warehouse, null, null);
        $ids = collect($due)->pluck('product_id')->all();
        if ($ids === []) {
            return ['created' => 0, 'count' => null];
        }

        $result = $this->plan(
            warehouse: $warehouse,
            user: $user,
            plannedAt: now()->toDateString(),
            zone: null,
            categoryId: null,
            inventoryClass: null,
            productIds: $ids,
            notes: 'Généré automatiquement selon la fréquence et la priorité ABC.',
            responsibleId: $user->id,
        );

        return ['created' => count($ids), 'count' => $result['count']];
    }

    /** @return list<array<string, mixed>> */
    public function suggest(Warehouse $warehouse, ?string $categoryId, ?string $inventoryClass): array
    {
        $products = Product::query()
            ->with(['category:id,name', 'saleUnits', 'unitModel'])
            ->where('is_active', true)
            ->whereNotIn('product_type', Product::nonStockableTypes())
            ->when($categoryId, fn ($query) => $query->where('category_id', $categoryId))
            ->when($inventoryClass, fn ($query) => $query->where('inventory_class', $inventoryClass))
            ->orderBy('name')
            ->get();

        $varianceCounts = InventoryCountItem::query()
            ->whereIn('product_id', $products->pluck('id'))
            ->whereNotNull('entered_quantity')
            ->whereColumn('counted_quantity', '!=', 'system_quantity')
            ->whereHas('inventoryCount', fn ($query) => $query->where('count_type', 'cycle')->where('warehouse_id', $warehouse->id))
            ->selectRaw('product_id, COUNT(*) as errors')
            ->groupBy('product_id')
            ->pluck('errors', 'product_id');

        $rows = [];
        foreach ($products as $product) {
            $due = $product->next_count_at === null || $product->next_count_at->lte(now()->startOfDay());
            $overdueDays = $product->next_count_at ? max(0, $product->next_count_at->diffInDays(now(), false)) : 30;
            $errors = (int) ($varianceCounts[$product->id] ?? 0);
            $classScore = match ($product->inventory_class) {
                'A' => 40,
                'B' => 25,
                'C' => 10,
                default => 15,
            };
            $score = $classScore + min(40, $overdueDays) + ($errors * 8);
            if (! $due && $errors === 0 && $inventoryClass === null) {
                continue;
            }

            $rows[] = [
                'product_id' => $product->id,
                'name' => $product->name,
                'sku' => $product->sku,
                'category' => $product->category?->name,
                'inventory_class' => $product->inventory_class,
                'count_frequency' => $product->count_frequency,
                'last_counted_at' => optional($product->last_counted_at)?->toDateString(),
                'next_count_at' => optional($product->next_count_at)?->toDateString(),
                'error_count' => $errors,
                'score' => $score,
                'priority' => $errors > 0 || $product->inventory_class === 'A' ? 'high' : 'normal',
            ];
        }

        usort($rows, fn (array $a, array $b) => $b['score'] <=> $a['score']);

        return $rows;
    }

    /** @return array<string, mixed> */
    public function dashboard(Warehouse $warehouse): array
    {
        $counts = InventoryCount::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('count_type', 'cycle')
            ->get();

        $planned = $counts->where('status', InventoryCountStatus::Scheduled)->count();
        $completed = $counts->where('status', InventoryCountStatus::Completed)->count();
        $overdue = $counts->filter(function (InventoryCount $count) {
            return $count->status === InventoryCountStatus::Scheduled
                && $count->counted_at
                && $count->counted_at->lt(now()->startOfDay());
        })->count();

        $items = InventoryCountItem::query()
            ->whereNotNull('entered_quantity')
            ->whereHas('inventoryCount', fn ($query) => $query
                ->where('warehouse_id', $warehouse->id)
                ->where('count_type', 'cycle')
                ->where('status', InventoryCountStatus::Completed->value))
            ->with('product:id,name')
            ->get();

        $counted = $items->count();
        $matched = $items->filter(fn (InventoryCountItem $item) => (int) $item->counted_quantity === (int) ($item->system_quantity ?? 0))->count();
        $accuracy = $counted > 0 ? round(($matched / $counted) * 100, 1) : 100;

        $offenders = $items
            ->filter(fn (InventoryCountItem $item) => (int) $item->counted_quantity !== (int) ($item->system_quantity ?? 0))
            ->groupBy('product_id')
            ->map(fn ($group) => [
                'product_id' => $group->first()->product_id,
                'name' => $group->first()->product?->name,
                'variances' => $group->count(),
            ])
            ->sortByDesc('variances')
            ->take(5)
            ->values()
            ->all();

        return [
            'planned' => $planned,
            'completed' => $completed,
            'overdue' => $overdue,
            'accuracy' => $accuracy,
            'counted_lines' => $counted,
            'matched_lines' => $matched,
            'top_variances' => $offenders,
        ];
    }

    /** @return list<array<string, mixed>> */
    public function history(Product $product): array
    {
        return InventoryCountItem::query()
            ->where('product_id', $product->id)
            ->whereNotNull('entered_quantity')
            ->whereHas('inventoryCount', fn ($query) => $query->where('count_type', 'cycle'))
            ->with(['inventoryCount:id,count_number,counted_at,status,performed_by,approved_by', 'inventoryCount.performedBy:id,name', 'inventoryCount.approvedBy:id,name'])
            ->orderByDesc('created_at')
            ->limit(24)
            ->get()
            ->map(fn (InventoryCountItem $item) => [
                'count_number' => $item->inventoryCount?->count_number,
                'date' => optional($item->inventoryCount?->counted_at)?->toDateString(),
                'system_quantity' => $item->system_quantity,
                'physical_quantity' => $item->counted_quantity,
                'difference' => (int) $item->counted_quantity - (int) ($item->system_quantity ?? 0),
                'reason' => $item->variance_reason,
                'user' => $item->inventoryCount?->performedBy?->name,
                'approved_by' => $item->inventoryCount?->approvedBy?->name,
                'status' => $item->inventoryCount?->status?->value,
            ])
            ->all();
    }

    /**
     * @param  list<array{product_id: string, inventory_class?: string|null, count_frequency?: string|null}>  $rules
     */
    public function saveRules(array $rules, User $user): int
    {
        $updated = 0;
        foreach ($rules as $rule) {
            $product = Product::query()->find($rule['product_id'] ?? null);
            if (! $product) {
                continue;
            }
            $frequency = $rule['count_frequency'] ?? $product->count_frequency;
            $product->update([
                'inventory_class' => $rule['inventory_class'] ?? $product->inventory_class,
                'count_frequency' => $frequency,
                'next_count_at' => $product->next_count_at ?? $this->nextDate($frequency),
            ]);
            $updated++;
        }
        $this->auditLogService->log('cycle_count.rules_updated', $user, $user->id, ['updated' => $updated]);

        return $updated;
    }

    public function finalize(InventoryCount $count, User $user): array
    {
        if ($count->count_type !== 'cycle') {
            throw ValidationException::withMessages(['count_type' => ['Ce n’est pas un comptage cyclique.']]);
        }
        if (! in_array($count->status, [InventoryCountStatus::Approved, InventoryCountStatus::Confirmed], true)) {
            throw ValidationException::withMessages([
                'status' => ['Validez le comptage avant de générer les ajustements.'],
            ]);
        }

        $count->load(['warehouse', 'items.product']);

        return DB::transaction(function () use ($count, $user): array {
            foreach ($count->items as $item) {
                if ($item->entered_quantity === null) {
                    continue;
                }
                $physical = (int) $item->counted_quantity;
                $system = (int) ($item->system_quantity ?? 0);
                $delta = $physical - $system;
                $product = $item->product ?? Product::query()->findOrFail($item->product_id);

                if ($delta !== 0) {
                    $this->movementService->record([
                        'warehouse' => $count->warehouse,
                        'product' => $product,
                        'movement_type' => $delta > 0
                            ? InventoryMovementType::AdjustmentIn
                            : InventoryMovementType::AdjustmentOut,
                        'quantity' => abs($delta),
                        'reference' => $count,
                        'performed_by' => $user->id,
                        'notes' => trim("Comptage cyclique {$count->count_number} · stock système {$system} · stock physique {$physical} · différence ".($delta > 0 ? '+' : '').$delta.($item->variance_reason ? ' · '.$item->variance_reason : '')),
                        'occurred_at' => now(),
                    ]);
                }

                $frequency = $product->count_frequency ?: match ($product->inventory_class) {
                    'A' => 'weekly',
                    'B' => 'monthly',
                    default => 'quarterly',
                };
                $product->update([
                    'last_counted_at' => now()->toDateString(),
                    'next_count_at' => $this->nextDate($frequency),
                    'count_frequency' => $frequency,
                ]);
            }

            $count->update([
                'status' => InventoryCountStatus::Completed,
                'lock_movements' => false,
                'completed_at' => now(),
                'approved_by' => $count->approved_by ?: $user->id,
            ]);
            $this->auditLogService->log('cycle_count.completed', $count, $user->id, ['status' => 'completed']);

            return $this->fullCountService->present($count->fresh());
        });
    }

    private function resolveProducts(Warehouse $warehouse, array $productIds, ?string $categoryId, ?string $inventoryClass)
    {
        $query = Product::query()
            ->with(['saleUnits', 'unitModel'])
            ->where('is_active', true)
            ->whereNotIn('product_type', Product::nonStockableTypes());

        if ($productIds !== []) {
            $query->whereIn('id', $productIds);
        } else {
            $suggested = collect($this->suggest($warehouse, $categoryId, $inventoryClass))->pluck('product_id');
            $query->whereIn('id', $suggested);
        }

        return $query->get();
    }

    private function nextDate(?string $frequency): ?string
    {
        $date = Carbon::now();

        return match ($frequency) {
            'daily' => $date->addDay()->toDateString(),
            'weekly' => $date->addWeek()->toDateString(),
            'monthly' => $date->addMonth()->toDateString(),
            'quarterly' => $date->addMonths(3)->toDateString(),
            default => $date->addMonth()->toDateString(),
        };
    }

    private function nextNumber(string $tenantId): string
    {
        $year = now()->year;
        $prefix = "CC-{$year}-";
        $last = InventoryCount::query()
            ->where('tenant_id', $tenantId)
            ->where('count_number', 'like', $prefix.'%')
            ->orderByDesc('count_number')
            ->value('count_number');
        $next = 1;
        if (is_string($last) && preg_match('/(\d+)$/', $last, $matches)) {
            $next = ((int) $matches[1]) + 1;
        }

        return $prefix.str_pad((string) $next, 3, '0', STR_PAD_LEFT);
    }
}
