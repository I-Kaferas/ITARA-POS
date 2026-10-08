<?php

namespace App\Exceptions\Domain;

final class DiscoveryError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.discovery';
    }

    public function httpStatus(): int
    {
        return 404;
    }

    public function defaultTitle(): string
    {
        return 'Aucun appareil trouvé sur le réseau.';
    }

    public function defaultDetail(): ?string
    {
        return 'Assurez-vous d’être sur le même Wi-Fi que le Master, puis relancez la recherche.';
    }
}
