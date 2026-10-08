<?php

namespace App\Exceptions\Domain;

final class NetworkError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.network';
    }

    public function httpStatus(): int
    {
        return 503;
    }

    public function defaultTitle(): string
    {
        return 'Connexion Internet indisponible.';
    }

    public function defaultDetail(): ?string
    {
        return 'La vente est enregistrée localement et sera synchronisée automatiquement.';
    }
}
