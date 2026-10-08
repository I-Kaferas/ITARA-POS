<?php

namespace App\Exceptions\Domain;

final class SyncError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.sync';
    }

    public function httpStatus(): int
    {
        return 503;
    }

    public function defaultTitle(): string
    {
        return 'Synchronisation interrompue.';
    }

    public function defaultDetail(): ?string
    {
        return 'Vous pouvez continuer à vendre. La synchro reprendra automatiquement.';
    }
}
