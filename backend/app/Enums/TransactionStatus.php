<?php

namespace App\Enums;

enum TransactionStatus: string
{
    case Draft = 'draft';
    case Pending = 'pending';
    case Completed = 'completed';
    case Voided = 'voided';
    case Cancelled = 'cancelled';

    public function isFinal(): bool
    {
        return $this === self::Completed
            || $this === self::Voided
            || $this === self::Cancelled;
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
