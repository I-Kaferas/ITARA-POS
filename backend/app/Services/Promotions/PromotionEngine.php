<?php

namespace App\Services\Promotions;

use App\DTOs\Cart\CartItemInput;
use App\DTOs\Promotions\PromotionEvaluationResult;
use App\Enums\PromotionType;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Promotion;
use App\Models\Store;
use App\Support\Money\MoneyMath;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class PromotionEngine
{
    /**
     * @param  list<CartItemInput>  $items
     */
    public function evaluate(array $items, Store $store, ?Customer $customer = null): PromotionEvaluationResult
    {
        $lineCount = count($items);
        if ($lineCount === 0) {
            return new PromotionEvaluationResult([], 0, []);
        }

        $now = $this->nowFor($store);
        $categories = $this->categoryMap($items);
        $lineWinners = [];
        $globalWinner = null;

        foreach ($this->candidates($store) as $promotion) {
            if (! $this->isEligible($promotion, $store, $customer, $now)) {
                continue;
            }

            [$lineAmounts, $global] = $this->quote($promotion, $items, $categories);

            foreach ($lineAmounts as $index => $amount) {
                $cap = MoneyMath::multiply($items[$index]->unitPrice, $items[$index]->quantity);
                $amount = MoneyMath::clamp($amount, 0, $cap);
                if ($amount <= 0) {
                    continue;
                }

                $current = $lineWinners[$index]['amount'] ?? 0;
                $currentPriority = $lineWinners[$index]['priority'] ?? PHP_INT_MIN;
                if ($amount > $current || ($amount === $current && $promotion->priority > $currentPriority)) {
                    $lineWinners[$index] = [
                        'amount' => $amount,
                        'priority' => $promotion->priority,
                        'promotion' => $promotion,
                    ];
                }
            }

            if ($global > 0 && ($globalWinner === null || $global > $globalWinner['amount'] || ($global === $globalWinner['amount'] && $promotion->priority > $globalWinner['priority']))) {
                $globalWinner = [
                    'amount' => $global,
                    'priority' => $promotion->priority,
                    'promotion' => $promotion,
                ];
            }
        }

        $lineDiscounts = array_fill(0, $lineCount, 0);
        $applied = [];

        foreach ($lineWinners as $index => $winner) {
            $lineDiscounts[$index] = $winner['amount'];
            $applied[] = $this->appliedRow($winner['promotion'], $winner['amount'], $items[$index]->lineId);
        }

        $globalDiscount = 0;
        if ($globalWinner !== null) {
            $globalDiscount = $globalWinner['amount'];
            $applied[] = $this->appliedRow($globalWinner['promotion'], $globalDiscount, null);
        }

        return new PromotionEvaluationResult($lineDiscounts, $globalDiscount, $applied);
    }

    /** @param  list<array{promotion_id?: string, amount?: int}>  $applied */
    public function recordUsage(array $applied): void
    {
        $ids = collect($applied)
            ->filter(fn (array $row) => (int) ($row['amount'] ?? 0) > 0 && ! empty($row['promotion_id']))
            ->pluck('promotion_id')
            ->unique()
            ->values();

        if ($ids->isEmpty()) {
            return;
        }

        Promotion::query()->whereIn('id', $ids)->increment('uses_count');
    }

    /** @return Collection<int, Promotion> */
    public function eligible(Store $store, ?Customer $customer = null): Collection
    {
        $now = $this->nowFor($store);

        return $this->candidates($store)
            ->filter(fn (Promotion $promotion) => $this->isEligible($promotion, $store, $customer, $now))
            ->values();
    }

    /** @return Collection<int, Promotion> */
    private function candidates(Store $store): Collection
    {
        return Promotion::query()
            ->with(['items', 'customers'])
            ->where('is_active', true)
            ->where(fn ($query) => $query
                ->whereNull('store_id')
                ->orWhere('store_id', $store->id))
            ->orderByDesc('priority')
            ->orderBy('name')
            ->get();
    }

    private function isEligible(Promotion $promotion, Store $store, ?Customer $customer, Carbon $now): bool
    {
        if ($promotion->store_id !== null && $promotion->store_id !== $store->id) {
            return false;
        }

        if ($promotion->starts_at !== null && $now->lt($promotion->starts_at)) {
            return false;
        }

        if ($promotion->ends_at !== null && $now->gt($promotion->ends_at)) {
            return false;
        }

        if ($promotion->max_uses !== null && $promotion->uses_count >= $promotion->max_uses) {
            return false;
        }

        if ($promotion->type === PromotionType::CustomerDiscount) {
            if ($customer === null || ! $promotion->customers->contains('customer_id', $customer->id)) {
                return false;
            }
        } elseif ($promotion->customers->isNotEmpty()) {
            if ($customer === null || ! $promotion->customers->contains('customer_id', $customer->id)) {
                return false;
            }
        }

        return $this->matchesSchedule($promotion, $now);
    }

    private function matchesSchedule(Promotion $promotion, Carbon $now): bool
    {
        $schedule = $promotion->schedule ?? [];
        $days = array_map('intval', $schedule['days_of_week'] ?? []);
        if ($days !== [] && ! in_array((int) $now->format('N'), $days, true)) {
            return false;
        }

        $start = $schedule['time_start'] ?? null;
        $end = $schedule['time_end'] ?? null;

        if ($promotion->type === PromotionType::TimeBased && (! $start || ! $end)) {
            return false;
        }

        if (! $start || ! $end) {
            return true;
        }

        $clock = $now->format('H:i');
        if ($start <= $end) {
            return $clock >= $start && $clock <= $end;
        }

        return $clock >= $start || $clock <= $end;
    }

    /**
     * @param  list<CartItemInput>  $items
     * @param  array<string, ?string>  $categories
     * @return array{0: array<int, int>, 1: int}
     */
    private function quote(Promotion $promotion, array $items, array $categories): array
    {
        return match ($promotion->type) {
            PromotionType::BuyXGetY => [$this->quoteBuyXGetY($promotion, $items), 0],
            PromotionType::Bundle => [$this->quoteBundle($promotion, $items), 0],
            PromotionType::FixedDiscount => $this->quoteFixed($promotion, $items, $categories),
            PromotionType::TimeBased => [$this->quoteTimeBased($promotion, $items, $categories), 0],
            default => [$this->quotePercent($promotion, $items, $categories), 0],
        };
    }

    /**
     * @param  list<CartItemInput>  $items
     * @param  array<string, ?string>  $categories
     * @return array<int, int>
     */
    private function quotePercent(Promotion $promotion, array $items, array $categories): array
    {
        $percent = (float) ($promotion->discount_percent ?? 0);
        if ($percent <= 0) {
            return [];
        }

        $amounts = [];
        foreach ($items as $index => $item) {
            if (! $this->lineMatches($promotion, $item, $categories)) {
                continue;
            }
            if ($item->quantity < max(1, (int) $promotion->min_quantity)) {
                continue;
            }
            $amounts[$index] = MoneyMath::percentOf(
                MoneyMath::multiply($item->unitPrice, $item->quantity),
                $percent,
            );
        }

        return $amounts;
    }

    /**
     * @param  list<CartItemInput>  $items
     * @param  array<string, ?string>  $categories
     * @return array{0: array<int, int>, 1: int}
     */
    private function quoteFixed(Promotion $promotion, array $items, array $categories): array
    {
        $amount = (int) ($promotion->discount_amount ?? 0);
        if ($amount <= 0) {
            return [[], 0];
        }

        if ($promotion->items->isEmpty() && $promotion->category_id === null) {
            return [[], $amount];
        }

        $amounts = [];
        foreach ($items as $index => $item) {
            if ($this->lineMatches($promotion, $item, $categories)) {
                $amounts[$index] = $amount;
            }
        }

        return [$amounts, 0];
    }

    /**
     * @param  list<CartItemInput>  $items
     * @param  array<string, ?string>  $categories
     * @return array<int, int>
     */
    private function quoteTimeBased(Promotion $promotion, array $items, array $categories): array
    {
        $special = (int) ($promotion->discount_amount ?? 0);
        $amounts = [];

        foreach ($items as $index => $item) {
            if (! $this->lineMatches($promotion, $item, $categories)) {
                continue;
            }

            if ($special > 0 && $special < $item->unitPrice) {
                $amounts[$index] = ($item->unitPrice - $special) * $item->quantity;
                continue;
            }

            $percent = (float) ($promotion->discount_percent ?? 0);
            if ($percent > 0) {
                $amounts[$index] = MoneyMath::percentOf(
                    MoneyMath::multiply($item->unitPrice, $item->quantity),
                    $percent,
                );
            }
        }

        return $amounts;
    }

    /**
     * Buy 2 get 1 free: free units = floor(qty / (buy + get)) * get, at 100% unless a lower percent is set.
     *
     * @param  list<CartItemInput>  $items
     * @return array<int, int>
     */
    private function quoteBuyXGetY(Promotion $promotion, array $items): array
    {
        $buy = max(1, (int) ($promotion->buy_quantity ?? 2));
        $get = max(1, (int) ($promotion->get_quantity ?? 1));
        $percent = $promotion->discount_percent === null ? 100 : (float) $promotion->discount_percent;
        if ($percent <= 0) {
            return [];
        }

        $rate = min(100, $percent) / 100;
        $matching = [];
        foreach ($items as $index => $item) {
            if ($this->roleMatches($promotion, $item, ['trigger', 'reward', 'target'])) {
                $matching[$index] = $item;
            }
        }

        if ($matching === []) {
            return [];
        }

        if ($this->isSameProductDeal($promotion)) {
            $amounts = [];
            foreach ($matching as $index => $item) {
                $free = intdiv($item->quantity, $buy + $get) * $get;
                if ($free < 1) {
                    continue;
                }
                $amounts[$index] = (int) round($free * $item->unitPrice * $rate);
            }

            return $amounts;
        }

        $triggerQty = 0;
        foreach ($items as $item) {
            if ($this->roleMatches($promotion, $item, ['trigger', 'target'])) {
                $triggerQty += $item->quantity;
            }
        }

        $freeLeft = intdiv($triggerQty, $buy) * $get;
        if ($freeLeft < 1) {
            return [];
        }

        $rewards = [];
        foreach ($items as $index => $item) {
            if ($this->roleMatches($promotion, $item, ['reward'])) {
                $rewards[$index] = $item;
            }
        }
        if ($rewards === []) {
            $rewards = $matching;
        }

        $amounts = [];
        foreach ($rewards as $index => $item) {
            if ($freeLeft < 1) {
                break;
            }
            $free = min($item->quantity, $freeLeft);
            $amounts[$index] = (int) round($free * $item->unitPrice * $rate);
            $freeLeft -= $free;
        }

        return $amounts;
    }

    /**
     * @param  list<CartItemInput>  $items
     * @return array<int, int>
     */
    private function quoteBundle(Promotion $promotion, array $items): array
    {
        $requirements = $promotion->items->where('role', 'bundle')->values();
        if ($requirements->isEmpty() || $promotion->bundle_price === null) {
            return [];
        }

        $times = PHP_INT_MAX;
        $regular = 0;
        $weights = array_fill(0, count($items), 0);

        foreach ($requirements as $requirement) {
            $need = max(1, (int) $requirement->quantity);
            $have = 0;
            $unit = null;
            foreach ($items as $index => $item) {
                if (! $this->itemMatchesRow($requirement->product_id, $requirement->product_variant_id, $item)) {
                    continue;
                }
                $have += $item->quantity;
                $unit ??= $item->unitPrice;
                $weights[$index] += MoneyMath::multiply($item->unitPrice, min($item->quantity, $need));
            }

            if ($unit === null) {
                return [];
            }

            $times = min($times, intdiv($have, $need));
            $regular += $unit * $need;
        }

        if ($times < 1 || $regular <= (int) $promotion->bundle_price) {
            return [];
        }

        $discount = ($regular - (int) $promotion->bundle_price) * $times;
        $allocated = MoneyMath::allocateProportionally($discount, $weights);
        $amounts = [];
        foreach ($allocated as $index => $amount) {
            if ($amount > 0) {
                $amounts[$index] = $amount;
            }
        }

        return $amounts;
    }

    /**
     * @param  list<CartItemInput>  $items
     * @param  array<string, ?string>  $categories
     */
    private function lineMatches(Promotion $promotion, CartItemInput $item, array $categories): bool
    {
        if ($promotion->type === PromotionType::CategoryDiscount) {
            return $promotion->category_id !== null
                && $item->productId !== null
                && ($categories[$item->productId] ?? null) === $promotion->category_id;
        }

        if ($promotion->items->isEmpty()) {
            return true;
        }

        return $this->roleMatches($promotion, $item, ['target', 'trigger', 'bundle']);
    }

    /** @param  list<string>  $roles */
    private function roleMatches(Promotion $promotion, CartItemInput $item, array $roles): bool
    {
        if ($promotion->items->isEmpty()) {
            return true;
        }

        return $promotion->items->contains(function ($row) use ($item, $roles) {
            if (! in_array($row->role, $roles, true)) {
                return false;
            }

            return $this->itemMatchesRow($row->product_id, $row->product_variant_id, $item);
        });
    }

    private function itemMatchesRow(?string $productId, ?string $variantId, CartItemInput $item): bool
    {
        if ($variantId !== null && $variantId !== $item->productVariantId) {
            return false;
        }

        return $productId === null || $productId === $item->productId;
    }

    private function isSameProductDeal(Promotion $promotion): bool
    {
        return $promotion->items->pluck('product_id')->filter()->unique()->count() <= 1;
    }

    /**
     * @param  list<CartItemInput>  $items
     * @return array<string, ?string>
     */
    private function categoryMap(array $items): array
    {
        $ids = array_values(array_unique(array_filter(array_map(
            fn (CartItemInput $item) => $item->productId,
            $items,
        ))));

        if ($ids === []) {
            return [];
        }

        return Product::query()->whereIn('id', $ids)->pluck('category_id', 'id')->all();
    }

    private function nowFor(Store $store): Carbon
    {
        $store->loadMissing('branch.company');
        $timezone = $store->branch?->company?->timezone ?: config('app.timezone');

        try {
            return now($timezone);
        } catch (\Throwable) {
            return now();
        }
    }

    /** @return array{promotion_id: string, name: string, type: string, amount: int, line_id: ?string} */
    private function appliedRow(Promotion $promotion, int $amount, ?string $lineId): array
    {
        return [
            'promotion_id' => $promotion->id,
            'name' => $promotion->name,
            'type' => $promotion->type->value,
            'amount' => $amount,
            'line_id' => $lineId,
        ];
    }
}
