<?php

namespace App\Enums;

enum SalePaymentMethod: string
{
    case Cash = 'cash';
    case MobileMoney = 'mobile_money';
    case Card = 'card';
    case BankTransfer = 'bank_transfer';
    case Credit = 'credit';
    case Wallet = 'wallet';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function label(): string
    {
        return match ($this) {
            self::Cash => 'Cash',
            self::MobileMoney => 'Mobile Money',
            self::Card => 'Card',
            self::BankTransfer => 'Bank transfer',
            self::Credit => 'Credit',
            self::Wallet => 'Wallet',
        };
    }

    public function requiresCustomer(): bool
    {
        return match ($this) {
            self::Credit, self::Wallet => true,
            default => false,
        };
    }
}
