<?php

namespace App\Exceptions\Domain;

final class PrinterError extends DomainError
{
    public function errorCode(): string
    {
        return 'errors.printer';
    }

    public function httpStatus(): int
    {
        return 502;
    }

    public function defaultTitle(): string
    {
        return 'Impression impossible.';
    }

    public function defaultDetail(): ?string
    {
        return 'Vérifiez que l’imprimante est allumée et connectée, puis réessayez.';
    }
}
