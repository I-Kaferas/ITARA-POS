<?php

namespace App\Enums;

enum LocationType: string
{
    case Company = 'company';
    case Branch = 'branch';
    case Store = 'store';
    case Warehouse = 'warehouse';
    case Room = 'room';
    case Table = 'table';
    case Address = 'address';
    case Other = 'other';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
