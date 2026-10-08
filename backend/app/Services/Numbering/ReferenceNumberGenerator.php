<?php

namespace App\Services\Numbering;

use App\Enums\NumberingDocumentType;
use App\Enums\NumberingResetPolicy;
use App\Models\Branch;
use App\Models\NumberingRule;
use App\Models\NumberingSequence;
use DateTimeInterface;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ReferenceNumberGenerator
{
    /**
     * Allocate and return the next reference for a document type.
     */
    public function next(
        NumberingDocumentType|string $type,
        string $tenantId,
        ?string $branchId = null,
        DateTimeInterface|string|null $at = null,
    ): string {
        $documentType = $this->normalizeType($type);
        $moment = $this->moment($at);

        return DB::transaction(function () use ($documentType, $tenantId, $branchId, $moment): string {
            $resolved = $this->resolveRule($documentType, $tenantId, $branchId);
            $periodKey = $this->periodKey($resolved['reset_policy'], $moment);

            $sequence = NumberingSequence::query()
                ->where('tenant_id', $tenantId)
                ->where('scope_key', $resolved['scope_key'])
                ->where('document_type', $documentType)
                ->where('period_key', $periodKey)
                ->lockForUpdate()
                ->first();

            if ($sequence === null) {
                $sequence = NumberingSequence::query()->create([
                    'tenant_id' => $tenantId,
                    'branch_id' => $resolved['branch_id'],
                    'scope_key' => $resolved['scope_key'],
                    'document_type' => $documentType,
                    'period_key' => $periodKey,
                    'last_value' => max(0, $resolved['starting_number'] - 1),
                ]);

                $sequence = NumberingSequence::query()
                    ->whereKey($sequence->id)
                    ->lockForUpdate()
                    ->firstOrFail();
            }

            $sequence->last_value = (int) $sequence->last_value + 1;
            $sequence->save();

            return $this->format($resolved, (int) $sequence->last_value, $moment, $branchId);
        });
    }

    /**
     * Format the next value without consuming a sequence slot.
     */
    public function preview(
        NumberingDocumentType|string $type,
        string $tenantId,
        ?string $branchId = null,
        DateTimeInterface|string|null $at = null,
    ): string {
        $documentType = $this->normalizeType($type);
        $moment = $this->moment($at);
        $resolved = $this->resolveRule($documentType, $tenantId, $branchId);
        $periodKey = $this->periodKey($resolved['reset_policy'], $moment);

        $last = NumberingSequence::query()
            ->where('tenant_id', $tenantId)
            ->where('scope_key', $resolved['scope_key'])
            ->where('document_type', $documentType)
            ->where('period_key', $periodKey)
            ->value('last_value');

        $next = $last === null
            ? (int) $resolved['starting_number']
            : ((int) $last) + 1;

        return $this->format($resolved, $next, $moment, $branchId);
    }

    /**
     * Effective configuration for every document type (defaults + overrides).
     *
     * @return list<array<string, mixed>>
     */
    public function catalog(string $tenantId, ?string $branchId = null): array
    {
        $rules = NumberingRule::query()
            ->where('tenant_id', $tenantId)
            ->where('is_active', true)
            ->where(function ($query) use ($branchId): void {
                $query->where('scope_key', NumberingRule::TENANT_SCOPE);
                if ($branchId) {
                    $query->orWhere(function ($inner) use ($branchId): void {
                        $inner->where('scope_key', $branchId)
                            ->where('branch_id', $branchId);
                    });
                }
            })
            ->get()
            ->groupBy(fn (NumberingRule $rule) => $rule->document_type->value);

        return collect(NumberingDocumentType::cases())
            ->map(function (NumberingDocumentType $type) use ($rules, $tenantId, $branchId): array {
                $resolved = $this->resolveRule($type, $tenantId, $branchId, $rules);

                return [
                    'document_type' => $type->value,
                    'label' => $type->label(),
                    'prefix' => $resolved['prefix'],
                    'pattern' => $resolved['pattern'],
                    'padding' => $resolved['padding'],
                    'reset_policy' => $resolved['reset_policy']->value,
                    'starting_number' => $resolved['starting_number'],
                    'scope_key' => $resolved['scope_key'],
                    'branch_id' => $resolved['branch_id'],
                    'source' => $resolved['source'],
                    'rule_id' => $resolved['rule_id'],
                    'preview' => $this->format($resolved, (int) $resolved['starting_number'], now(), $branchId),
                ];
            })
            ->values()
            ->all();
    }

    /**
     * @param  array{
     *     document_type: string,
     *     prefix: string,
     *     pattern?: string|null,
     *     padding?: int|null,
     *     reset_policy?: string|null,
     *     starting_number?: int|null,
     *     branch_id?: string|null,
     *     is_active?: bool|null,
     * }  $data
     */
    public function upsertRule(string $tenantId, array $data): NumberingRule
    {
        $documentType = $this->normalizeType($data['document_type']);
        $branchId = $data['branch_id'] ?? null;

        if ($branchId !== null) {
            $branch = Branch::query()->find($branchId);
            if ($branch === null || $branch->tenant_id !== $tenantId) {
                throw ValidationException::withMessages([
                    'branch_id' => ['Branche introuvable pour ce tenant.'],
                ]);
            }
        }

        $defaults = $this->defaultsFor($documentType);
        $scopeKey = NumberingRule::scopeKeyFor($branchId);

        $rule = NumberingRule::query()->updateOrCreate(
            [
                'tenant_id' => $tenantId,
                'scope_key' => $scopeKey,
                'document_type' => $documentType,
            ],
            [
                'branch_id' => $branchId,
                'prefix' => strtoupper(trim($data['prefix'])),
                'pattern' => $data['pattern'] ?? $defaults['pattern'],
                'padding' => (int) ($data['padding'] ?? $defaults['padding']),
                'reset_policy' => $data['reset_policy'] ?? $defaults['reset_policy'],
                'starting_number' => (int) ($data['starting_number'] ?? $defaults['starting_number']),
                'is_active' => $data['is_active'] ?? true,
            ],
        );

        return $rule->fresh(['branch:id,name,code']);
    }

    /**
     * @param  Collection<string, Collection<int, NumberingRule>>|null  $preloaded
     * @return array{
     *     prefix: string,
     *     pattern: string,
     *     padding: int,
     *     reset_policy: NumberingResetPolicy,
     *     starting_number: int,
     *     scope_key: string,
     *     branch_id: string|null,
     *     source: string,
     *     rule_id: string|null,
     * }
     */
    public function resolveRule(
        NumberingDocumentType $type,
        string $tenantId,
        ?string $branchId = null,
        ?Collection $preloaded = null,
    ): array {
        $defaults = $this->defaultsFor($type);
        $typed = $preloaded?->get($type->value);

        $branchRule = null;
        $tenantRule = null;

        if ($typed !== null) {
            $branchRule = $branchId
                ? $typed->first(fn (NumberingRule $rule) => $rule->scope_key === $branchId)
                : null;
            $tenantRule = $typed->first(fn (NumberingRule $rule) => $rule->scope_key === NumberingRule::TENANT_SCOPE);
        } else {
            if ($branchId) {
                $branchRule = NumberingRule::query()
                    ->where('tenant_id', $tenantId)
                    ->where('document_type', $type)
                    ->where('scope_key', $branchId)
                    ->where('is_active', true)
                    ->first();
            }

            $tenantRule = NumberingRule::query()
                ->where('tenant_id', $tenantId)
                ->where('document_type', $type)
                ->where('scope_key', NumberingRule::TENANT_SCOPE)
                ->where('is_active', true)
                ->first();
        }

        $rule = $branchRule ?? $tenantRule;
        if ($rule === null) {
            return [
                'prefix' => $defaults['prefix'],
                'pattern' => $defaults['pattern'],
                'padding' => (int) $defaults['padding'],
                'reset_policy' => NumberingResetPolicy::from($defaults['reset_policy']),
                'starting_number' => (int) $defaults['starting_number'],
                // Defaults are tenant-wide; branch overrides create their own counters.
                'scope_key' => NumberingRule::TENANT_SCOPE,
                'branch_id' => null,
                'source' => 'default',
                'rule_id' => null,
            ];
        }

        return [
            'prefix' => $rule->prefix,
            'pattern' => $rule->pattern,
            'padding' => (int) $rule->padding,
            'reset_policy' => $rule->reset_policy,
            'starting_number' => (int) $rule->starting_number,
            'scope_key' => $rule->scope_key,
            'branch_id' => $rule->branch_id,
            'source' => $rule->branch_id ? 'branch' : 'tenant',
            'rule_id' => $rule->id,
        ];
    }

    /**
     * @param  array{
     *     prefix: string,
     *     pattern: string,
     *     padding: int,
     *     reset_policy?: NumberingResetPolicy,
     *     starting_number?: int,
     *     scope_key?: string,
     *     branch_id?: string|null,
     *     source?: string,
     *     rule_id?: string|null,
     * }  $rule
     */
    public function format(array $rule, int $sequence, DateTimeInterface $at, ?string $branchId = null): string
    {
        $branchCode = '';
        $resolvedBranchId = $rule['branch_id'] ?? $branchId;
        if ($resolvedBranchId) {
            $branchCode = (string) (Branch::query()->whereKey($resolvedBranchId)->value('code') ?? '');
        }

        $padded = str_pad((string) $sequence, max(1, (int) $rule['padding']), '0', STR_PAD_LEFT);
        $carbon = $at instanceof Carbon ? $at : Carbon::parse($at);

        $replacements = [
            '{prefix}' => strtoupper($rule['prefix']),
            '{year}' => $carbon->format('Y'),
            '{month}' => $carbon->format('m'),
            '{sequence}' => $padded,
            '{branch}' => strtoupper($branchCode),
        ];

        $formatted = strtr($rule['pattern'], $replacements);
        $formatted = preg_replace('/-{2,}/', '-', $formatted) ?? $formatted;

        return trim($formatted, '-');
    }

    private function normalizeType(NumberingDocumentType|string $type): NumberingDocumentType
    {
        if ($type instanceof NumberingDocumentType) {
            return $type;
        }

        return NumberingDocumentType::from($type);
    }

    private function moment(DateTimeInterface|string|null $at): Carbon
    {
        if ($at === null) {
            return now();
        }

        return Carbon::parse($at);
    }

    private function periodKey(NumberingResetPolicy $policy, Carbon $at): string
    {
        return match ($policy) {
            NumberingResetPolicy::Never => '',
            NumberingResetPolicy::Yearly => $at->format('Y'),
            NumberingResetPolicy::Monthly => $at->format('Y-m'),
        };
    }

    /** @return array{prefix: string, pattern: string, padding: int, reset_policy: string, starting_number: int} */
    private function defaultsFor(NumberingDocumentType $type): array
    {
        $defaults = config('numbering.defaults.'.$type->value);

        if (! is_array($defaults)) {
            throw ValidationException::withMessages([
                'document_type' => ["Aucun défaut de numérotation pour {$type->value}."],
            ]);
        }

        return $defaults;
    }
}
