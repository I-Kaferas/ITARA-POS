<?php

namespace App\Services\Tax;

use App\Enums\TaxKind;
use App\Models\Tax;
use App\Models\TaxGroup;
use App\Models\TaxRule;
use App\Support\Money\MoneyMath;
use Illuminate\Support\Collection;

/**
 * Configurable tax calculator. Locale-specific rates live in tenant tables /
 * tax profiles — this class only applies generic mechanics (priority, compound,
 * inclusive, kinds).
 */
class TaxEngine
{
    /**
     * @param  list<string>|null  $taxIds
     * @return array{
     *     net: int,
     *     tax_total: int,
     *     withholding_total: int,
     *     total: int,
     *     lines: list<array<string, mixed>>
     * }
     */
    public function calculate(
        int $amount,
        bool $amountIsInclusive = false,
        ?array $taxIds = null,
        ?string $taxGroupId = null,
        ?string $taxClassId = null,
        ?string $country = null,
        ?string $region = null,
    ): array {
        $taxes = $this->resolveTaxes($taxIds, $taxGroupId, $taxClassId, $country, $region);

        return $this->quote($amount, $amountIsInclusive, $taxes);
    }

    /**
     * @param  Collection<int, Tax>|list<Tax>  $taxes
     * @return array{
     *     net: int,
     *     tax_total: int,
     *     withholding_total: int,
     *     total: int,
     *     lines: list<array<string, mixed>>
     * }
     */
    public function quote(int $amount, bool $amountIsInclusive, Collection|array $taxes): array
    {
        $amount = max(0, $amount);
        /** @var Collection<int, Tax> $sorted */
        $sorted = Collection::make($taxes)
            ->filter(fn (Tax $tax) => $tax->is_active)
            ->sortBy([
                ['priority', 'asc'],
                ['name', 'asc'],
            ])
            ->values();

        if ($sorted->isEmpty()) {
            return [
                'net' => $amount,
                'tax_total' => 0,
                'withholding_total' => 0,
                'total' => $amount,
                'lines' => [],
            ];
        }

        return $amountIsInclusive
            ? $this->quoteInclusive($amount, $sorted)
            : $this->quoteExclusive($amount, $sorted);
    }

    /**
     * Resolve active taxes from explicit ids, a group, or matching rules.
     *
     * @param  list<string>|null  $taxIds
     * @return Collection<int, Tax>
     */
    public function resolveTaxes(
        ?array $taxIds = null,
        ?string $taxGroupId = null,
        ?string $taxClassId = null,
        ?string $country = null,
        ?string $region = null,
    ): Collection {
        if (is_array($taxIds) && $taxIds !== []) {
            return Tax::query()
                ->where('is_active', true)
                ->whereIn('id', $taxIds)
                ->get();
        }

        if ($taxGroupId) {
            $group = TaxGroup::query()
                ->where('is_active', true)
                ->with(['taxes' => fn ($q) => $q->where('is_active', true)])
                ->find($taxGroupId);

            return $group?->taxes ?? collect();
        }

        return $this->resolveFromRules($taxClassId, $country, $region);
    }

    /**
     * @return Collection<int, Tax>
     */
    public function resolveFromRules(?string $taxClassId, ?string $country = null, ?string $region = null): Collection
    {
        if (! $taxClassId) {
            return collect();
        }

        $rules = TaxRule::query()
            ->where('is_active', true)
            ->where('tax_class_id', $taxClassId)
            ->with(['tax', 'taxGroup.taxes'])
            ->orderBy('priority')
            ->orderBy('name')
            ->get();

        $matched = $rules->first(function (TaxRule $rule) use ($country, $region) {
            if ($rule->country && $country && strtoupper($rule->country) !== strtoupper($country)) {
                return false;
            }
            if ($rule->country && ! $country) {
                return false;
            }
            if ($rule->region && $region && mb_strtolower($rule->region) !== mb_strtolower($region)) {
                return false;
            }
            if ($rule->region && ! $region) {
                return false;
            }

            return true;
        });

        // Fall back to the first class-wide rule (no country/region constraint).
        $matched ??= $rules->first(fn (TaxRule $rule) => $rule->country === null && $rule->region === null);

        if ($matched === null) {
            return collect();
        }

        if ($matched->tax_group_id && $matched->taxGroup) {
            return $matched->taxGroup->taxes->where('is_active', true)->values();
        }

        if ($matched->tax && $matched->tax->is_active) {
            return collect([$matched->tax]);
        }

        return collect();
    }

    /**
     * @param  Collection<int, Tax>  $taxes
     * @return array{net: int, tax_total: int, withholding_total: int, total: int, lines: list<array<string, mixed>>}
     */
    private function quoteExclusive(int $amount, Collection $taxes): array
    {
        $collected = 0;
        $withheld = 0;
        $lines = [];

        foreach ($taxes as $tax) {
            $kind = $tax->kind instanceof TaxKind ? $tax->kind : TaxKind::tryFrom((string) $tax->kind) ?? TaxKind::Tax;
            $taxable = $tax->is_compound ? $amount + $collected : $amount;
            $taxAmount = $this->amountFor($kind, $taxable, (float) $tax->rate);

            if ($kind->isWithheld()) {
                $withheld += $taxAmount;
            } elseif ($kind->isCollectible()) {
                $collected += $taxAmount;
            }

            $lines[] = $this->line($tax, $kind, $taxable, $taxAmount, inclusive: false);
        }

        return [
            'net' => $amount,
            'tax_total' => $collected,
            'withholding_total' => $withheld,
            'total' => $amount + $collected,
            'lines' => $lines,
        ];
    }

    /**
     * @param  Collection<int, Tax>  $taxes
     * @return array{net: int, tax_total: int, withholding_total: int, total: int, lines: list<array<string, mixed>>}
     */
    private function quoteInclusive(int $gross, Collection $taxes): array
    {
        $collectible = $taxes->filter(function (Tax $tax) {
            $kind = $tax->kind instanceof TaxKind ? $tax->kind : TaxKind::tryFrom((string) $tax->kind) ?? TaxKind::Tax;

            return $kind->isCollectible() && ! $kind->isWithheld();
        });

        $compoundRate = 0.0;
        $simpleRate = 0.0;
        foreach ($collectible as $tax) {
            $rate = (float) $tax->rate;
            if ($tax->is_compound) {
                $compoundRate = ((100 + $compoundRate) * (1 + $rate / 100)) - 100;
            } else {
                $simpleRate += $rate;
            }
        }
        $combinedRate = $simpleRate + $compoundRate;

        $taxTotal = MoneyMath::extractInclusiveTax($gross, $combinedRate);
        $net = max(0, $gross - $taxTotal);

        $lines = [];
        $allocated = 0;
        $withheld = 0;
        $collectibleList = $collectible->values();
        $lastIndex = $collectibleList->count() - 1;

        foreach ($taxes as $tax) {
            $kind = $tax->kind instanceof TaxKind ? $tax->kind : TaxKind::tryFrom((string) $tax->kind) ?? TaxKind::Tax;

            if (! $kind->isCollectible() || $kind->isWithheld()) {
                $taxable = $net;
                $taxAmount = $kind->isWithheld()
                    ? MoneyMath::taxOnExclusive($net, (float) $tax->rate)
                    : 0;
                if ($kind->isWithheld()) {
                    $withheld += $taxAmount;
                }
                $lines[] = $this->line($tax, $kind, $taxable, $taxAmount, inclusive: true);

                continue;
            }

            $index = $collectibleList->search(fn (Tax $row) => $row->id === $tax->id);
            if ($index === false) {
                continue;
            }

            if ($combinedRate <= 0) {
                $share = 0;
            } elseif ($index === $lastIndex) {
                $share = $taxTotal - $allocated;
            } else {
                $share = (int) round($taxTotal * ((float) $tax->rate) / $combinedRate);
                $allocated += $share;
            }

            $lines[] = $this->line($tax, $kind, $net, max(0, $share), inclusive: true);
        }

        return [
            'net' => $net,
            'tax_total' => $taxTotal,
            'withholding_total' => $withheld,
            'total' => $gross,
            'lines' => $lines,
        ];
    }

    private function amountFor(TaxKind $kind, int $taxable, float $rate): int
    {
        if (! $kind->isCollectible() || $rate <= 0 || $taxable <= 0) {
            return 0;
        }

        return MoneyMath::taxOnExclusive($taxable, $rate);
    }

    /** @return array<string, mixed> */
    private function line(Tax $tax, TaxKind $kind, int $taxable, int $taxAmount, bool $inclusive): array
    {
        return [
            'tax_id' => $tax->id,
            'name' => $tax->name,
            'code' => $tax->code,
            'kind' => $kind->value,
            'rate' => (float) $tax->rate,
            'priority' => (int) $tax->priority,
            'is_inclusive' => $inclusive || (bool) $tax->is_inclusive,
            'is_compound' => (bool) $tax->is_compound,
            'is_withheld' => $kind->isWithheld(),
            'taxable_amount' => $taxable,
            'tax_amount' => $taxAmount,
        ];
    }
}
