<?php

namespace App\Enums;

enum CustomerPaymentMethod: string
{
    case Cash = 'cash';
    case BankTransfer = 'bank_transfer';
    case Check = 'check';
    case MobileMoney = 'mobile_money';
    case Card = 'card';
    case StoreCredit = 'store_credit';
    case Other = 'other';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
