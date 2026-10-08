<?php

namespace App\Exceptions\Domain;

final class PairingError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.pairing';
    }

    public function httpStatus(): int
    {
        return 422;
    }

    public function defaultTitle(): string
    {
        return 'Appairage impossible.';
    }

    public function defaultDetail(): ?string
    {
        return 'Vérifiez le code affiché sur le Master et réessayez dans le délai imparti.';
    }
}
