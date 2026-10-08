<?php

namespace App\Services\Sync;

/**
 * Snapshot of a sync write used by ConflictResolutionEngine.
 */
final readonly class ConflictContext
{
    /**
     * @param  array<string, mixed>|null  $localPayload
     * @param  array<string, mixed>|null  $serverRecord
     */
    public function __construct(
        public string $entityType,
        public string $operation,
        public ?array $localPayload = null,
        public ?array $serverRecord = null,
        public ?string $baseVersion = null,
        public ?string $serverVersion = null,
        public bool $force = false,
        public bool $fromMaster = false,
        public ?string $conflictDomain = null,
        public ?string $syncDomain = null,
    ) {}

    /**
     * @param  array<string, mixed>|null  $localPayload
     * @param  array<string, mixed>|null  $serverRecord
     */
    public static function make(
        string $entityType,
        string $operation,
        ?array $localPayload = null,
        ?array $serverRecord = null,
        ?string $baseVersion = null,
        ?string $serverVersion = null,
        bool $force = false,
        bool $fromMaster = false,
        ?string $conflictDomain = null,
        ?string $syncDomain = null,
    ): self {
        return new self(
            entityType: $entityType,
            operation: $operation,
            localPayload: $localPayload,
            serverRecord: $serverRecord,
            baseVersion: $baseVersion,
            serverVersion: $serverVersion,
            force: $force,
            fromMaster: $fromMaster,
            conflictDomain: $conflictDomain,
            syncDomain: $syncDomain,
        );
    }

    public function serverStatus(): ?string
    {
        $status = $this->serverRecord['status'] ?? null;

        return is_string($status) ? strtolower($status) : null;
    }

    public function serverQuantity(): ?int
    {
        foreach (['quantity_on_hand', 'quantity', 'qty'] as $key) {
            if (isset($this->serverRecord[$key]) && is_numeric($this->serverRecord[$key])) {
                return (int) $this->serverRecord[$key];
            }
        }

        return null;
    }

    public function localQuantity(): ?int
    {
        foreach (['quantity_on_hand', 'quantity', 'qty', 'target_quantity'] as $key) {
            if (isset($this->localPayload[$key]) && is_numeric($this->localPayload[$key])) {
                return (int) $this->localPayload[$key];
            }
        }

        return null;
    }

    public function isStale(): bool
    {
        if ($this->baseVersion === null || $this->baseVersion === '' || $this->serverVersion === null || $this->serverVersion === '') {
            return false;
        }

        return $this->baseVersion !== $this->serverVersion;
    }
}
