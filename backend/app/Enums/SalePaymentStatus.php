<?php

namespace App\Enums;

enum SalePaymentStatus: string
{
    case Paid = 'paid';
    case Partial = 'partial';
    case OnCredit = 'on_credit';

    public static function fromAmounts(int $total, int $paidAmount): self
    {
        if ($paidAmount >= $total) {
            return self::Paid;
        }

        if ($paidAmount > 0) {
            return self::Partial;
        }

        return self::OnCredit;
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
