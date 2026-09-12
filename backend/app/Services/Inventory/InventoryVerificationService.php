<?php

namespace App\Services\Inventory;

use App\Models\InventoryMovement;
use App\Models\InventoryVerificationFinding;
use App\Models\InventoryVerificationPlan;
use App\Models\InventoryVerificationRun;
use App\Models\Product;
use App\Models\SaleItem;
use App\Models\StockBalance;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Audit\AuditLogService;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class InventoryVerificationService
{
    public function __construct(
        private readonly AuditLogService $auditLogService,
    ) {}

    public function createPlan(Warehouse $warehouse, User $user, array $data): InventoryVerificationPlan
    {
        $plan = InventoryVerificationPlan::query()->create([
            'tenant_id' => $warehouse->tenant_id,
            'name' => $data['name'],
            'warehouse_id' => $warehouse->id,
            'category_id' => $data['category_id'] ?? null,
            'inventory_class' => $data['inventory_class'] ?? null,
            'frequency' => $data['frequency'] ?? 'weekly',
            'responsible_id' => $data['responsible_id'] ?? $user->id,
            'next_run_at' => $data['next_run_at'] ?? now()->toDateString(),
            'notes' => $data['notes'] ?? null,
        ]);
        $this->auditLogService->log('verification_plan.created', $plan, $user->id, ['name' => $plan->name]);

        return $plan->load(['warehouse:id,name', 'responsible:id,name']);
    }

    public function dashboard(Warehouse $warehouse): array
    {
        $today = now()->startOfDay();
        $plans = InventoryVerificationPlan::query()->where('warehouse_id', $warehouse->id)->where('is_active', true)->get();
        $dueToday = $plans->filter(fn ($plan) => $plan->next_run_at && $plan->next_run_at->isSameDay($today))->count();
        $overdue = $plans->filter(fn ($plan) => $plan->next_run_at && $plan->next_run_at->lt($today))->count();
        $openFindings = InventoryVerificationFinding::query()
            ->where('status', 'open')
            ->whereHas('run', fn ($query) => $query->where('warehouse_id', $warehouse->id))
            ->get();
        $criticalProducts = $openFindings->where('severity', 'high')->pluck('product_id')->unique()->count();
        $scores = $this->productScores($warehouse);

        return [
            'due_today' => $dueToday,
            'overdue' => $overdue,
            'open_anomalies' => $openFindings->count(),
            'critical_products' => $criticalProducts,
            'reliability' => $scores['global'],
            'at_risk' => array_slice($scores['products'], 0, 5),
        ];
    }

    /** @return list<array<string, mixed>> */
    public function suggest(Warehouse $warehouse, ?string $categoryId, ?string $inventoryClass): array
    {
        $products = $this->candidateProducts($warehouse, $categoryId, $inventoryClass);
        $adjustments = InventoryMovement::query()
            ->where('warehouse_id', $warehouse->id)
            ->whereIn('movement_type', ['ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'LOSS', 'DAMAGE', 'INVENTORY_ADJUSTMENT_OUT', 'CYCLE_COUNT_ADJUSTMENT_OUT'])
            ->selectRaw('product_id, COUNT(*) as adjustments')
            ->groupBy('product_id')
            ->pluck('adjustments', 'product_id');
        $stockValue = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->selectRaw('product_id, SUM(quantity_on_hand) as qty')
            ->groupBy('product_id')
            ->pluck('qty', 'product_id');

        $rows = [];
        foreach ($products as $product) {
            $qty = (int) ($stockValue[$product->id] ?? 0);
            $value = $qty * max(1, (int) $product->cost_price);
            $errors = (int) ($adjustments[$product->id] ?? 0);
            $stale = $product->last_counted_at === null || $product->last_counted_at->lt(now()->subDays(30));
            $score = ($product->inventory_class === 'A' ? 40 : 10) + min(30, $errors * 6) + ($stale ? 15 : 0) + ($value > 0 ? 10 : 0);
            $rows[] = [
                'product_id' => $product->id,
                'name' => $product->name,
                'sku' => $product->sku,
                'inventory_class' => $product->inventory_class,
                'stock_value' => $value,
                'adjustments' => $errors,
                'priority' => $score >= 40 ? 'high' : 'normal',
                'score' => $score,
            ];
        }
        usort($rows, fn ($a, $b) => $b['score'] <=> $a['score']);

        return $rows;
    }

    public function run(?InventoryVerificationPlan $plan, Warehouse $warehouse, User $user, array $productIds = []): InventoryVerificationRun
    {
        $products = $productIds !== []
            ? Product::query()->with(['saleUnits', 'unitModel'])->whereIn('id', $productIds)->get()
            : $this->candidateProducts($warehouse, $plan?->category_id, $plan?->inventory_class);

        return DB::transaction(function () use ($plan, $warehouse, $user, $products): InventoryVerificationRun {
            $run = InventoryVerificationRun::query()->create([
                'tenant_id' => $warehouse->tenant_id,
                'plan_id' => $plan?->id,
                'reference' => $this->nextReference($warehouse->tenant_id),
                'warehouse_id' => $warehouse->id,
                'status' => 'analysis',
                'performed_by' => $user->id,
                'analyzed_at' => now(),
            ]);

            $productResults = [];
            $anomalyCount = 0;
            foreach ($products as $product) {
                $findings = $this->analyzeProduct($warehouse, $product);
                $checklist = $this->checklist($warehouse, $product, $findings);
                $score = $this->score($findings, (int) InventoryMovement::query()
                    ->where('warehouse_id', $warehouse->id)
                    ->where('product_id', $product->id)
                    ->whereIn('movement_type', ['ADJUSTMENT_OUT', 'LOSS', 'DAMAGE'])
                    ->count());
                foreach ($findings as $finding) {
                    $anomalyCount++;
                    InventoryVerificationFinding::query()->create([
                        'tenant_id' => $warehouse->tenant_id,
                        'run_id' => $run->id,
                        'product_id' => $product->id,
                        ...$finding,
                    ]);
                }
                $productResults[] = [
                    'product_id' => $product->id,
                    'name' => $product->name,
                    'score' => $score,
                    'grade' => $this->grade($score),
                    'checklist' => $checklist,
                    'anomalies' => count($findings),
                ];
            }

            $checked = count($productResults);
            $conforming = collect($productResults)->where('anomalies', 0)->count();
            $summary = [
                'products_checked' => $checked,
                'conforming' => $conforming,
                'anomalies' => $anomalyCount,
                'compliance_rate' => $checked > 0 ? round(($conforming / $checked) * 100, 1) : 100,
                'products' => $productResults,
            ];
            $run->update([
                'summary' => $summary,
                'status' => $anomalyCount > 0 ? 'anomalies' : 'validated',
                'validated_at' => $anomalyCount === 0 ? now() : null,
                'validated_by' => $anomalyCount === 0 ? $user->id : null,
            ]);
            if ($plan) {
                $plan->update(['next_run_at' => $this->nextDate($plan->frequency)]);
            }
            $this->auditLogService->log('verification_run.analyzed', $run, $user->id, $summary);

            return $run->fresh(['warehouse:id,name', 'performedBy:id,name', 'findings.product:id,name,sku']);
        });
    }

    public function resolveFinding(InventoryVerificationFinding $finding, User $user, string $status, ?string $note, ?string $action): InventoryVerificationFinding
    {
        $finding->update([
            'status' => $status,
            'note' => $note,
            'action_taken' => $action,
            'resolved_by' => $user->id,
            'resolved_at' => now(),
        ]);
        $run = $finding->run;
        $open = $run->findings()->where('status', 'open')->count();
        if ($open === 0 && $run->status !== 'validated') {
            $run->update(['status' => 'correction']);
        }
        $this->auditLogService->log('verification_finding.updated', $finding, $user->id, [
            'status' => $status,
            'old' => $finding->expected_value,
            'new' => $finding->actual_value,
            'action' => $action,
            'note' => $note,
        ]);

        return $finding->fresh(['product:id,name']);
    }

    public function validateRun(InventoryVerificationRun $run, User $user): InventoryVerificationRun
    {
        $run->update([
            'status' => 'validated',
            'validated_by' => $user->id,
            'validated_at' => now(),
        ]);
        $this->auditLogService->log('verification_run.validated', $run, $user->id, ['reference' => $run->reference]);

        return $run->fresh(['warehouse:id,name', 'performedBy:id,name', 'validatedBy:id,name', 'findings.product:id,name,sku']);
    }

    /** @return list<array<string, mixed>> */
    private function analyzeProduct(Warehouse $warehouse, Product $product): array
    {
        $findings = [];
        $onHand = (int) StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->sum('quantity_on_hand');
        $movementSum = (int) InventoryMovement::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->sum('quantity');

        if ($onHand < 0) {
            $findings[] = $this->finding('quantity', 'negative_stock', 'high', 'Stock négatif détecté.', '0', (string) $onHand);
        }
        if ($onHand !== $movementSum) {
            $findings[] = $this->finding(
                'quantity',
                'expected_mismatch',
                'high',
                'Le stock système ne correspond pas à la somme des mouvements.',
                (string) $movementSum,
                (string) $onHand,
            );
        }

        $expectedSaleQty = $this->expectedSaleQuantity($warehouse, $product);
        $actualSaleQty = abs((int) InventoryMovement::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->where('movement_type', 'SALE')
            ->sum('quantity'));
        if ($expectedSaleQty > 0 && $expectedSaleQty !== $actualSaleQty) {
            $findings[] = $this->finding(
                'movement',
                'sale_without_stock',
                'high',
                'Les ventes enregistrées ne correspondent pas aux sorties de stock.',
                (string) $expectedSaleQty,
                (string) $actualSaleQty,
            );
        }

        if ($product->tracksVolume()) {
            $bottle = (int) $product->bottle_volume_ml;
            $badUnit = SaleItem::query()
                ->where('product_id', $product->id)
                ->whereHas('sale', fn ($query) => $query->where('warehouse_id', $warehouse->id))
                ->whereNotNull('sale_unit_id')
                ->where('volume_ml', '>', 0)
                ->get()
                ->first(function (SaleItem $item) use ($product, $bottle) {
                    $unit = $product->saleUnits->firstWhere('id', $item->sale_unit_id);
                    if (! $unit) {
                        return false;
                    }
                    $expected = (int) $item->quantity * (int) $unit->volume_ml;

                    return (int) $item->volume_ml !== $expected || ($unit->is_base && $bottle > 0 && (int) $unit->volume_ml !== $bottle);
                });
            if ($badUnit) {
                $findings[] = $this->finding('unit', 'conversion_error', 'high', 'Erreur de conversion d’unité sur une vente.', (string) $bottle, (string) $badUnit->volume_ml);
            }
        }

        if ((int) $product->cost_price > 0 && (int) $product->base_price > 0 && (int) $product->cost_price > (int) $product->base_price) {
            $findings[] = $this->finding('financial', 'price_margin', 'warning', 'Le prix d’achat est supérieur au prix de vente.', (string) $product->base_price, (string) $product->cost_price);
        }

        return $findings;
    }

    /** @param  list<array<string, mixed>>  $findings
     * @return list<array{label: string, ok: bool}>
     */
    private function checklist(Warehouse $warehouse, Product $product, array $findings): array
    {
        $codes = collect($findings)->pluck('code');
        $lastMovement = InventoryMovement::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->exists();
        $onHand = (int) StockBalance::query()->where('warehouse_id', $warehouse->id)->where('product_id', $product->id)->sum('quantity_on_hand');
        $threshold = $product->effectiveLowStockThreshold();

        return [
            ['label' => 'Stock positif', 'ok' => $onHand >= 0 && ! $codes->contains('negative_stock')],
            ['label' => 'Dernier mouvement enregistré', 'ok' => $lastMovement || $onHand === 0],
            ['label' => 'Conversion correcte', 'ok' => ! $codes->contains('conversion_error')],
            ['label' => 'Prix valide', 'ok' => ! $codes->contains('price_margin')],
            ['label' => 'Pas de mouvement suspect', 'ok' => ! $codes->contains('sale_without_stock')],
            ['label' => 'Historique analysé', 'ok' => true],
            ['label' => 'Stock minimum respecté', 'ok' => $threshold === null || $onHand > $threshold],
        ];
    }

    private function expectedSaleQuantity(Warehouse $warehouse, Product $product): int
    {
        return (int) SaleItem::query()
            ->where('product_id', $product->id)
            ->whereHas('sale', fn ($query) => $query->where('warehouse_id', $warehouse->id))
            ->get()
            ->sum(fn (SaleItem $item) => $item->volume_ml && $item->volume_ml > 0 ? (int) $item->volume_ml : (int) $item->quantity);
    }

    /** @param  list<array<string, mixed>>  $findings */
    private function score(array $findings, int $adjustments): int
    {
        $score = 100 - (count($findings) * 12) - min(20, $adjustments * 2);

        return max(0, min(100, $score));
    }

    private function grade(int $score): string
    {
        if ($score >= 90) {
            return 'excellent';
        }
        if ($score >= 70) {
            return 'watch';
        }

        return 'action';
    }

    /** @return array<string, mixed> */
    private function finding(string $type, string $code, string $severity, string $title, string $expected, string $actual): array
    {
        return [
            'check_type' => $type,
            'code' => $code,
            'severity' => $severity,
            'status' => 'open',
            'title' => $title,
            'message' => $title,
            'expected_value' => $expected,
            'actual_value' => $actual,
        ];
    }

    private function candidateProducts(Warehouse $warehouse, ?string $categoryId, ?string $inventoryClass)
    {
        $ids = StockBalance::query()->where('warehouse_id', $warehouse->id)->distinct()->pluck('product_id');

        return Product::query()
            ->with(['saleUnits', 'unitModel'])
            ->where('is_active', true)
            ->whereNotIn('product_type', Product::nonStockableTypes())
            ->where(function ($query) use ($ids) {
                $query->whereIn('id', $ids)->orWhereNotNull('inventory_class');
            })
            ->when($categoryId, fn ($query) => $query->where('category_id', $categoryId))
            ->when($inventoryClass, fn ($query) => $query->where('inventory_class', $inventoryClass))
            ->orderBy('name')
            ->limit(80)
            ->get();
    }

    /** @return array{global: float, products: list<array<string, mixed>>} */
    private function productScores(Warehouse $warehouse): array
    {
        $open = InventoryVerificationFinding::query()
            ->with('product:id,name')
            ->where('status', 'open')
            ->whereHas('run', fn ($query) => $query->where('warehouse_id', $warehouse->id))
            ->get()
            ->groupBy('product_id');
        $products = [];
        foreach ($open as $productId => $findings) {
            $score = max(0, 100 - ($findings->count() * 12));
            $products[] = [
                'product_id' => $productId,
                'name' => $findings->first()?->product?->name,
                'score' => $score,
                'grade' => $this->grade($score),
            ];
        }
        usort($products, fn ($a, $b) => $a['score'] <=> $b['score']);
        $global = $products === [] ? 100 : round(collect($products)->avg('score'), 1);

        return ['global' => $global, 'products' => $products];
    }

    private function nextDate(string $frequency): string
    {
        $date = Carbon::now();

        return match ($frequency) {
            'daily' => $date->addDay()->toDateString(),
            'weekly' => $date->addWeek()->toDateString(),
            'monthly' => $date->addMonth()->toDateString(),
            'quarterly' => $date->addMonths(3)->toDateString(),
            default => $date->addWeek()->toDateString(),
        };
    }

    private function nextReference(string $tenantId): string
    {
        $year = now()->year;
        $prefix = "VER-{$year}-";
        $last = InventoryVerificationRun::query()
            ->where('tenant_id', $tenantId)
            ->where('reference', 'like', $prefix.'%')
            ->orderByDesc('reference')
            ->value('reference');
        $next = 1;
        if (is_string($last) && preg_match('/(\d+)$/', $last, $matches)) {
            $next = ((int) $matches[1]) + 1;
        }

        return $prefix.str_pad((string) $next, 4, '0', STR_PAD_LEFT);
    }
}
