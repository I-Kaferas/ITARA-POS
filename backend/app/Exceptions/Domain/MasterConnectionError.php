<?php

namespace App\Exceptions\Domain;

final class MasterConnectionError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.master_connection';
    }

    public function httpStatus(): int
    {
        return 503;
    }

    public function defaultTitle(): string
    {
        return 'Connexion au Master perdue.';
    }

    public function defaultDetail(): ?string
    {
        return 'La caisse continue en mode hors-ligne. La synchro reprendra dès que le Master sera joignable.';
    }
}
