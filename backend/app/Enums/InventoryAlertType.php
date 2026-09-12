<?php

namespace App\Enums;

enum InventoryAlertType: string
{
    case LowStock = 'LOW_STOCK';
    case OutOfStock = 'OUT_OF_STOCK';
    case ExpiringSoon = 'EXPIRING_SOON';
    case Expired = 'EXPIRED';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function label(): string
    {
        return match ($this) {
            self::LowStock => 'Low Stock',
            self::OutOfStock => 'Out of Stock',
            self::ExpiringSoon => 'Expiring Soon',
            self::Expired => 'Expired',
        };
    }
}
