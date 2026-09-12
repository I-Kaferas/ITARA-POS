<?php

namespace App\Enums;

enum SaleDocumentFormat: string
{
    case Thermal58 = 'thermal_58';
    case Thermal80 = 'thermal_80';
    case A4 = 'a4';
    case Pdf = 'pdf';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function label(): string
    {
        return match ($this) {
            self::Thermal58 => 'Thermal 58mm',
            self::Thermal80 => 'Thermal 80mm',
            self::A4 => 'A4',
            self::Pdf => 'PDF',
        };
    }

    public function isThermal(): bool
    {
        return match ($this) {
            self::Thermal58, self::Thermal80 => true,
            default => false,
        };
    }

    public function paperWidthMm(): ?int
    {
        return match ($this) {
            self::Thermal58 => 58,
            self::Thermal80 => 80,
            default => null,
        };
    }
}
