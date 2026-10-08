<?php

namespace App\Enums;

/**
 * Fiscal category of a tax definition.
 * Local rates and applicability live in tenant data / tax profiles, not here.
 */
enum TaxKind: string
{
    case Vat = 'vat';
    case Tax = 'tax';
    case Withholding = 'withholding';
    case Exempt = 'exempt';
    case ZeroRated = 'zero_rated';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    /** Whether the kind can produce a non-zero collected amount. */
    public function isCollectible(): bool
    {
        return match ($this) {
            self::Vat, self::Tax, self::Withholding => true,
            self::Exempt, self::ZeroRated => false,
        };
    }

    /** Withholding reduces net payable; it is not added to customer totals. */
    public function isWithheld(): bool
    {
        return $this === self::Withholding;
    }
}
