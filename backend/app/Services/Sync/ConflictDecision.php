<?php

namespace App\Services\Sync;

use App\Enums\ConflictAction;
use App\Enums\ConflictDomain;
use App\Enums\ConflictStrategy;

/**
 * Outcome of evaluating a sync conflict.
 */
final readonly class ConflictDecision
{
    /**
     * @param  array<string, mixed>  $meta
     */
    public function __construct(
        public ConflictAction $action,
        public ConflictDomain $domain,
        public ConflictStrategy $strategy,
        public ?string $code = null,
        public ?string $message = null,
        public bool $retryable = false,
        public array $meta = [],
    ) {}

    /**
     * @param  array<string, mixed>  $meta
     */
    public static function apply(ConflictDomain $domain, ConflictStrategy $strategy, array $meta = []): self
    {
        return new self(
            action: ConflictAction::Apply,
            domain: $domain,
            strategy: $strategy,
            meta: $meta,
        );
    }

    /**
     * @param  array<string, mixed>  $meta
     */
    public static function keepServer(
        ConflictDomain $domain,
        ConflictStrategy $strategy,
        string $code,
        string $message,
        array $meta = [],
    ): self {
        return new self(
            action: ConflictAction::KeepServer,
            domain: $domain,
            strategy: $strategy,
            code: $code,
            message: $message,
            meta: $meta,
        );
    }

    /**
     * @param  array<string, mixed>  $meta
     */
    public static function reject(
        ConflictDomain $domain,
        ConflictStrategy $strategy,
        string $code,
        string $message,
        bool $retryable = false,
        array $meta = [],
    ): self {
        return new self(
            action: ConflictAction::Reject,
            domain: $domain,
            strategy: $strategy,
            code: $code,
            message: $message,
            retryable: $retryable,
            meta: $meta,
        );
    }

    /**
     * @param  array<string, mixed>  $meta
     */
    public static function rewriteAsMovement(
        ConflictDomain $domain,
        ConflictStrategy $strategy,
        int $delta,
        string $message,
        array $meta = [],
    ): self {
        return new self(
            action: ConflictAction::RewriteAsMovement,
            domain: $domain,
            strategy: $strategy,
            code: 'use_stock_movements',
            message: $message,
            meta: array_merge(['delta' => $delta], $meta),
        );
    }

    public function allowsWrite(): bool
    {
        return $this->action === ConflictAction::Apply;
    }

    public function isConflict(): bool
    {
        return $this->action === ConflictAction::Reject
            || $this->action === ConflictAction::RewriteAsMovement;
    }

    /**
     * Shape used by OfflineSyncService outcome envelopes.
     *
     * @return array{status: string, error: ?string, conflict_code: ?string, retryable: bool}
     */
    public function toSyncOutcome(): array
    {
        if ($this->action === ConflictAction::Apply) {
            return [
                'status' => 'apply',
                'error' => null,
                'conflict_code' => null,
                'retryable' => false,
            ];
        }

        if ($this->action === ConflictAction::KeepServer) {
            return [
                'status' => 'keep_server',
                'error' => $this->message,
                'conflict_code' => $this->code,
                'retryable' => false,
            ];
        }

        return [
            'status' => 'conflict',
            'error' => $this->message,
            'conflict_code' => $this->code,
            'retryable' => $this->retryable,
        ];
    }
}
