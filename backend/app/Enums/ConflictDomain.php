<?php

namespace App\Enums;

enum ConflictDomain: string
{
    case Sales = 'sales';
    case Stock = 'stock';
    case Configuration = 'configuration';
    case Default = 'default';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
