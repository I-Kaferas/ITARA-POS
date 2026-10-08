<?php

namespace App\Exceptions\Domain;

final class AuthenticationError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.authentication';
    }

    public function httpStatus(): int
    {
        return 401;
    }

    public function defaultTitle(): string
    {
        return 'Session expirée.';
    }

    public function defaultDetail(): ?string
    {
        return 'Reconnectez-vous pour continuer.';
    }
}
