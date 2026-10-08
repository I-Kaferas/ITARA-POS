<?php

namespace App\Enums;

enum TaxComputationType: string
{
    case Percentage = 'percentage';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
