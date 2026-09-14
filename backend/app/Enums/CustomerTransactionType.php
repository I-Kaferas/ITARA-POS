<?php

namespace App\Enums;

enum CustomerTransactionType: string
{
    case Sale = 'SALE';
    case SaleReturn = 'SALE_RETURN';
    case Payment = 'PAYMENT';
    case CreditNote = 'CREDIT_NOTE';
    case OpeningBalance = 'OPENING_BALANCE';
    case Adjustment = 'ADJUSTMENT';
    case LoyaltyEarn = 'LOYALTY_EARN';
    case LoyaltyRedeem = 'LOYALTY_REDEEM';
    case LoyaltyReversal = 'LOYALTY_REVERSAL';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    /** Customer owes us more. */
    public function increasesReceivable(): bool
    {
        return match ($this) {
            self::Sale,
            self::OpeningBalance,
            self::Adjustment => true,
            default => false,
        };
    }

    public function isReceivable(): bool
    {
        return in_array($this, [self::Sale, self::OpeningBalance], true);
    }

    public function earnsLoyalty(): bool
    {
        return $this === self::Sale;
    }
}
