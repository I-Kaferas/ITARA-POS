<?php

namespace App\Enums;

enum PartyKind: string
{
    case Person = 'person';
    case Organization = 'organization';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
