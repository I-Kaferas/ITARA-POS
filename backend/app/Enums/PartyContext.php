<?php

namespace App\Enums;

enum PartyContext: string
{
    case Pos = 'pos';
    case Restaurant = 'restaurant';
    case Hotel = 'hotel';
    case Crm = 'crm';
    case Billing = 'billing';
    case Loyalty = 'loyalty';
    case Supplier = 'supplier';
    case Employee = 'employee';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function label(): string
    {
        return match ($this) {
            self::Pos => 'POS Customer',
            self::Restaurant => 'Restaurant Customer',
            self::Hotel => 'Hotel Guest',
            self::Crm => 'CRM Contact',
            self::Billing => 'Billing Party',
            self::Loyalty => 'Loyalty Member',
            self::Supplier => 'Supplier',
            self::Employee => 'Employee',
        };
    }
}
