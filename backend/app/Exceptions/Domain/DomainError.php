<?php

namespace App\Exceptions\Domain;

use Exception;
use Throwable;

/**
 * Typed domain error with a stable code and user-facing title/detail.
 * Never leak stack traces or SQL noise to clients.
 */
abstract class DomainError extends Exception
{
    public function __construct(
        string $message = '',
        private readonly ?string $detail = null,
        private readonly array $context = [],
        int $code = 0,
        ?Throwable $previous = null,
    ) {
        parent::__construct($message !== '' ? $message : $this->defaultTitle(), $code, $previous);
    }

    abstract public function errorCode(): string;

    abstract public function httpStatus(): int;

    abstract public function defaultTitle(): string;

    abstract public function defaultDetail(): ?string;

    public function title(): string
    {
        $message = trim($this->getMessage());

        return $message !== '' ? $message : $this->defaultTitle();
    }

    public function detail(): ?string
    {
        $detail = $this->detail ?? $this->defaultDetail();

        if ($detail === null) {
            return null;
        }

        $trimmed = trim($detail);

        return $trimmed !== '' ? $trimmed : null;
    }

    /** @return array<string, mixed> */
    public function context(): array
    {
        return $this->context;
    }

    public function userMessage(): string
    {
        $detail = $this->detail();

        return $detail === null
            ? $this->title()
            : $this->title()."\n".$detail;
    }

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return array_filter([
            'code' => $this->errorCode(),
            'message' => $this->errorCode(),
            'title' => $this->title(),
            'detail' => $this->detail(),
            'context' => $this->context === [] ? null : $this->context,
        ], static fn ($value) => $value !== null);
    }
}
