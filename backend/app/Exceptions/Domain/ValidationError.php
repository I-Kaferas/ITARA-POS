<?php

namespace App\Exceptions\Domain;

final class ValidationError extends DomainError
{
    /** @param  array<string, list<string>>  $errors */
    public function __construct(
        string $message = '',
        ?string $detail = null,
        private readonly array $errors = [],
        array $context = [],
        ?\Throwable $previous = null,
    ) {
        parent::__construct($message, $detail, $context, 0, $previous);
    }

    public function errorCode(): string
    {
        return 'errors.validation';
    }

    public function httpStatus(): int
    {
        return 422;
    }

    public function defaultTitle(): string
    {
        return 'Informations incomplètes ou incorrectes.';
    }

    public function defaultDetail(): ?string
    {
        return 'Vérifiez les champs indiqués puis réessayez.';
    }

    /** @return array<string, list<string>> */
    public function errors(): array
    {
        return $this->errors;
    }

    public function toArray(): array
    {
        $payload = parent::toArray();

        if ($this->errors !== []) {
            $payload['errors'] = $this->errors;
        }

        return $payload;
    }
}
