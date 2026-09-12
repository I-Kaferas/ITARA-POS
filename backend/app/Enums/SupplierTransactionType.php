<?php

namespace App\Enums;

enum SupplierTransactionType: string
{
    case Purchase = 'PURCHASE';
    case Payment = 'PAYMENT';
    case CreditNote = 'CREDIT_NOTE';
    case DebitNote = 'DEBIT_NOTE';
    case OpeningBalance = 'OPENING_BALANCE';
    case Adjustment = 'ADJUSTMENT';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function increasesDebt(): bool
    {
        return match ($this) {
            self::Purchase,
            self::DebitNote,
            self::OpeningBalance,
            self::Adjustment => true,
            default => false,
        };
    }

    public function isPayable(): bool
    {
        return in_array($this, [self::Purchase, self::DebitNote, self::OpeningBalance], true);
    }
}
