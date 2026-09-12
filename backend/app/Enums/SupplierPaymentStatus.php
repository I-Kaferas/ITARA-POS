<?php

namespace App\Enums;

enum SupplierPaymentStatus: string
{
    case Completed = 'completed';
    case Void = 'void';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
