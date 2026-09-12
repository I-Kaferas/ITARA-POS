<?php

namespace App\Enums;

enum InventoryCountStatus: string
{
    case Draft = 'draft';
    case Scheduled = 'scheduled';
    case InProgress = 'in_progress';
    case Counted = 'counted';
    case Review = 'review';
    case Approved = 'approved';
    case Confirmed = 'confirmed';
    case Completed = 'completed';
    case Cancelled = 'cancelled';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
