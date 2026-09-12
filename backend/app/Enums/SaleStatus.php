<?php

namespace App\Enums;

enum SaleStatus: string
{
    case Draft = 'draft';
    case Completed = 'completed';
    case Voided = 'voided';

    public function isFinal(): bool
    {
        return $this === self::Completed || $this === self::Voided;
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
