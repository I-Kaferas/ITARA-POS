<?php

namespace App\Enums;

enum SaleInvoiceStatus: string
{
    case Issued = 'issued';
    case Cancelled = 'cancelled';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
