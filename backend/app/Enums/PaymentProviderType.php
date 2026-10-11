<?php

namespace App\Enums;

enum PaymentProviderType: string
{
    case Cash = 'cash';
    case MobileMoney = 'mobile_money';
    case Card = 'card';
    case BankTransfer = 'bank_transfer';
    case Credit = 'credit';
    case Wallet = 'wallet';
    case Room = 'room';

    public static function forMethod(SalePaymentMethod $method): self
    {
        return self::from($method->value);
    }
}
