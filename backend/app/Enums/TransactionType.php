<?php

namespace App\Enums;

enum TransactionType: string
{
    case Sale = 'sale';
    case Purchase = 'purchase';
    case Payment = 'payment';
    case Refund = 'refund';
    case Expense = 'expense';
    case Transfer = 'transfer';
    case Adjustment = 'adjustment';

    public function referencePrefix(): string
    {
        return match ($this) {
            self::Sale => 'TXN-SAL',
            self::Purchase => 'TXN-PUR',
            self::Payment => 'TXN-PAY',
            self::Refund => 'TXN-REF',
            self::Expense => 'TXN-EXP',
            self::Transfer => 'TXN-TRF',
            self::Adjustment => 'TXN-ADJ',
        };
    }

    public function defaultPaymentStatus(): TransactionPaymentStatus
    {
        return match ($this) {
            self::Transfer, self::Adjustment => TransactionPaymentStatus::NotApplicable,
            self::Payment, self::Refund, self::Expense => TransactionPaymentStatus::Paid,
            self::Sale, self::Purchase => TransactionPaymentStatus::Unpaid,
        };
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
