<?php

namespace App\Exceptions\Domain;

final class PermissionError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.permission';
    }

    public function httpStatus(): int
    {
        return 403;
    }

    public function defaultTitle(): string
    {
        return 'Action non autorisée.';
    }

    public function defaultDetail(): ?string
    {
        return 'Demandez à un responsable d’approuver ou de vous attribuer le droit.';
    }
}
