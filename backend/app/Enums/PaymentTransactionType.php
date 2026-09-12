<?php

namespace App\Enums;

enum PaymentTransactionType: string
{
    case Payment = 'payment';
    case Refund = 'refund';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
