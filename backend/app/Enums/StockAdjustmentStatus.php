<?php

namespace App\Enums;

enum StockAdjustmentStatus: string
{
    case Draft = 'draft';
    case Approved = 'approved';
    case Completed = 'completed';
    case Cancelled = 'cancelled';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
