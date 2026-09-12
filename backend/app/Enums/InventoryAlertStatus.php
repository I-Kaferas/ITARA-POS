<?php

namespace App\Enums;

enum InventoryAlertStatus: string
{
    case Active = 'active';
    case Acknowledged = 'acknowledged';
    case Resolved = 'resolved';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
