<?php

namespace App\Enums;

enum PosTableStatus: string
{
    case Available = 'available';
    case Occupied = 'occupied';
    case Reserved = 'reserved';
    case Cleaning = 'cleaning';
    case Inactive = 'inactive';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function isOpenable(): bool
    {
        return $this === self::Available || $this === self::Cleaning;
    }
}
