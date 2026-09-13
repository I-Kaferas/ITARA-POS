<?php

namespace App\Enums;

enum PriceType: string
{
    case Base = 'base';
    case Retail = 'retail';
    case Wholesale = 'wholesale';
    case Vip = 'vip';
    case Special = 'special';
    case Distributor = 'distributor';
    case Promo = 'promo';

    /** @return list<string> */
    public static function sellableValues(): array
    {
        return [
            self::Retail->value,
            self::Wholesale->value,
            self::Vip->value,
            self::Special->value,
        ];
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
