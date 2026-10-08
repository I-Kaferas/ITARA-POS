<?php

namespace App\Services\Sync;

use App\Enums\ConflictDomain;
use App\Enums\ConflictStrategy;
use Illuminate\Support\Arr;

/**
 * Domain-configurable sync conflict resolver.
 *
 * Defaults (override in config/conflict_resolution.php):
 * - sales → never overwrite completed sales
 * - stock → use stock movements
 * - configuration → master configuration wins
 */
class ConflictResolutionEngine
{
    /** @var array<string, mixed>|null */
    private ?array $configCache = null;

    /** @var array<string, ConflictDomain>|null */
    private ?array $entityIndex = null;

    public function evaluate(ConflictContext $context): ConflictDecision
    {
        $domain = $this->resolveDomain($context);
        $strategy = $this->strategyFor($domain);

        return match ($strategy) {
            ConflictStrategy::NeverOverwriteCompleted => $this->resolveSales($context, $domain, $strategy),
            ConflictStrategy::StockMovements => $this->resolveStock($context, $domain, $strategy),
            ConflictStrategy::MasterWins => $this->resolveMasterWins($context, $domain, $strategy),
            ConflictStrategy::ServerWins => $this->resolveServerWins($context, $domain, $strategy),
            ConflictStrategy::ClientWins => ConflictDecision::apply($domain, $strategy),
            ConflictStrategy::Manual => $this->resolveManual($context, $domain, $strategy),
        };
    }

    public function resolveDomain(ConflictContext $context): ConflictDomain
    {
        if ($context->conflictDomain !== null && $context->conflictDomain !== '') {
            return ConflictDomain::tryFrom($context->conflictDomain) ?? ConflictDomain::Default;
        }

        $entity = strtolower(trim($context->entityType));
        $index = $this->entityIndex();

        if (isset($index[$entity])) {
            return $index[$entity];
        }

        return ConflictDomain::tryFrom((string) config('conflict_resolution.default_domain', 'default'))
            ?? ConflictDomain::Default;
    }

    public function strategyFor(ConflictDomain $domain): ConflictStrategy
    {
        $raw = (string) Arr::get($this->config(), "domains.{$domain->value}.strategy", ConflictStrategy::Manual->value);

        return ConflictStrategy::tryFrom($raw) ?? ConflictStrategy::Manual;
    }

    /**
     * Public catalog of domain → strategy for admin / device manifests.
     *
     * @return array<string, array{strategy: string, entity_types: list<string>}>
     */
    public function catalog(): array
    {
        $out = [];
        foreach ($this->config()['domains'] ?? [] as $code => $definition) {
            if (! is_array($definition)) {
                continue;
            }
            $out[(string) $code] = [
                'strategy' => (string) ($definition['strategy'] ?? ConflictStrategy::Manual->value),
                'entity_types' => array_values(array_map('strval', $definition['entity_types'] ?? [])),
            ];
        }

        return $out;
    }

    /**
     * Merge configuration payloads: master always wins on overlapping keys.
     *
     * @param  array<string, mixed>  $master
     * @param  array<string, mixed>  $slave
     * @return array<string, mixed>
     */
    public function mergeConfiguration(array $master, array $slave): array
    {
        return array_replace_recursive($slave, $master);
    }

    private function resolveSales(ConflictContext $context, ConflictDomain $domain, ConflictStrategy $strategy): ConflictDecision
    {
        $status = $context->serverStatus();
        $final = $this->finalStatuses($domain);

        if ($status === null || ! in_array($status, $final, true)) {
            return ConflictDecision::apply($domain, $strategy);
        }

        $operation = strtolower($context->operation);
        $mutable = $this->domainList($domain, 'mutable_operations', ['update', 'delete', 'void', 'overwrite']);

        if (! in_array($operation, $mutable, true)) {
            // create / complete with matching idempotency → keep server (already final)
            return ConflictDecision::keepServer(
                $domain,
                $strategy,
                'completed_sale',
                'La vente est déjà finalisée sur le serveur.',
                ['status' => $status, 'operation' => $operation],
            );
        }

        return ConflictDecision::reject(
            $domain,
            $strategy,
            'completed_sale',
            'Impossible d’écraser une vente finalisée.',
            meta: ['status' => $status, 'operation' => $operation],
        );
    }

    private function resolveStock(ConflictContext $context, ConflictDomain $domain, ConflictStrategy $strategy): ConflictDecision
    {
        $operation = strtolower($context->operation);
        $overwrites = $this->domainList($domain, 'overwrite_operations', [
            'set_quantity', 'overwrite', 'overwrite_balance', 'replace_balance', 'set_balance',
        ]);
        $movements = $this->domainList($domain, 'movement_operations', [
            'create', 'movement', 'adjust', 'transfer', 'receive', 'issue',
        ]);

        if (in_array($operation, $movements, true)) {
            return ConflictDecision::apply($domain, $strategy, ['via' => 'movement']);
        }

        if (! in_array($operation, $overwrites, true)) {
            // Unknown stock write — still require movements rather than absolute sets.
            if ($context->localQuantity() !== null && $context->serverQuantity() !== null) {
                return $this->stockOverwriteDecision($context, $domain, $strategy);
            }

            return ConflictDecision::apply($domain, $strategy);
        }

        return $this->stockOverwriteDecision($context, $domain, $strategy);
    }

    private function stockOverwriteDecision(
        ConflictContext $context,
        ConflictDomain $domain,
        ConflictStrategy $strategy,
    ): ConflictDecision {
        $serverQty = $context->serverQuantity();
        $localQty = $context->localQuantity();

        if ($serverQty !== null && $localQty !== null && $serverQty !== $localQty) {
            return ConflictDecision::rewriteAsMovement(
                $domain,
                $strategy,
                $localQty - $serverQty,
                'Le stock se synchronise par mouvements, pas par écrasement de quantité.',
                [
                    'server_quantity' => $serverQty,
                    'local_quantity' => $localQty,
                ],
            );
        }

        return ConflictDecision::reject(
            $domain,
            $strategy,
            'use_stock_movements',
            'Le stock se synchronise par mouvements, pas par écrasement de quantité.',
            meta: [
                'operation' => strtolower($context->operation),
            ],
        );
    }

    private function resolveMasterWins(ConflictContext $context, ConflictDomain $domain, ConflictStrategy $strategy): ConflictDecision
    {
        if ($context->fromMaster) {
            return ConflictDecision::apply($domain, $strategy, ['source' => 'master']);
        }

        // Slave / client configuration never overwrites master, even with force.
        if ($context->serverRecord !== null || $context->isStale()) {
            return ConflictDecision::keepServer(
                $domain,
                $strategy,
                'master_wins',
                'La configuration maître prévaut.',
                ['operation' => strtolower($context->operation)],
            );
        }

        // No master row yet — first write may seed from the client.
        return ConflictDecision::apply($domain, $strategy, ['source' => 'seed']);
    }

    private function resolveServerWins(ConflictContext $context, ConflictDomain $domain, ConflictStrategy $strategy): ConflictDecision
    {
        if ($context->force) {
            return ConflictDecision::apply($domain, $strategy);
        }

        if ($context->serverRecord !== null || $context->isStale()) {
            return ConflictDecision::keepServer(
                $domain,
                $strategy,
                'server_wins',
                'La copie serveur est conservée.',
            );
        }

        return ConflictDecision::apply($domain, $strategy);
    }

    private function resolveManual(ConflictContext $context, ConflictDomain $domain, ConflictStrategy $strategy): ConflictDecision
    {
        if ($context->force) {
            return ConflictDecision::apply($domain, $strategy);
        }

        if ($context->isStale()) {
            return ConflictDecision::reject(
                $domain,
                $strategy,
                'stale_version',
                'Le document a été modifié sur le serveur depuis la copie locale.',
            );
        }

        return ConflictDecision::apply($domain, $strategy);
    }

    /** @return list<string> */
    private function finalStatuses(ConflictDomain $domain): array
    {
        return $this->domainList($domain, 'final_statuses', ['completed', 'voided', 'merged']);
    }

    /**
     * @param  list<string>  $fallback
     * @return list<string>
     */
    private function domainList(ConflictDomain $domain, string $key, array $fallback): array
    {
        $values = Arr::get($this->config(), "domains.{$domain->value}.{$key}", $fallback);
        if (! is_array($values)) {
            return $fallback;
        }

        return array_values(array_map(
            static fn ($value) => strtolower((string) $value),
            $values,
        ));
    }

    /** @return array<string, ConflictDomain> */
    private function entityIndex(): array
    {
        if ($this->entityIndex !== null) {
            return $this->entityIndex;
        }

        $index = [];
        foreach ($this->config()['domains'] ?? [] as $code => $definition) {
            $domain = ConflictDomain::tryFrom((string) $code);
            if ($domain === null || ! is_array($definition)) {
                continue;
            }
            foreach ($definition['entity_types'] ?? [] as $entity) {
                $index[strtolower((string) $entity)] = $domain;
            }
        }

        return $this->entityIndex = $index;
    }

    /** @return array<string, mixed> */
    private function config(): array
    {
        return $this->configCache ??= config('conflict_resolution', []);
    }
}
