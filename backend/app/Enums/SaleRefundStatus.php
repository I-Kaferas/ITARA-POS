<?php

namespace App\Enums;

enum SaleRefundStatus: string
{
    case Completed = 'completed';
    case Failed = 'failed';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
