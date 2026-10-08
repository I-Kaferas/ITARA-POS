<?php

namespace App\Exceptions\Domain;

final class DatabaseError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.database';
    }

    public function httpStatus(): int
    {
        return 500;
    }

    public function defaultTitle(): string
    {
        return 'Enregistrement impossible pour le moment.';
    }

    public function defaultDetail(): ?string
    {
        return 'Réessayez dans un instant. Si le problème continue, contactez le support.';
    }
}
