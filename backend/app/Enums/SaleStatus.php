<?php

namespace App\Enums;

enum SaleStatus: string
{
    case Draft = 'draft';
    case Pending = 'pending';
    case Completed = 'completed';
    case Voided = 'voided';
    case Merged = 'merged';

    public function isFinal(): bool
    {
        return $this === self::Completed
            || $this === self::Voided
            || $this === self::Merged;
    }

    public function isOpen(): bool
    {
        return $this === self::Pending || $this === self::Draft;
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
