<?php

namespace App\Enums;

enum NumberingResetPolicy: string
{
    case Never = 'never';
    case Yearly = 'yearly';
    case Monthly = 'monthly';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
