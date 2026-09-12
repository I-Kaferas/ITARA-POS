<?php

namespace App\Enums;

enum BatchAllocationStrategy: string
{
    case Fifo = 'FIFO';
    case Fefo = 'FEFO';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
