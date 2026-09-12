<?php

namespace App\Enums;

enum SerialNumberStatus: string
{
    case Available = 'available';
    case Reserved = 'reserved';
    case Sold = 'sold';
    case Damaged = 'damaged';
    case Lost = 'lost';
    case InTransit = 'in_transit';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
