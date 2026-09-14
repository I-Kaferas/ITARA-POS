<?php

namespace App\Enums;

enum PromotionType: string
{
    case PercentageDiscount = 'percentage_discount';
    case FixedDiscount = 'fixed_discount';
    case BuyXGetY = 'buy_x_get_y';
    case Bundle = 'bundle';
    case QuantityDiscount = 'quantity_discount';
    case CategoryDiscount = 'category_discount';
    case CustomerDiscount = 'customer_discount';
    case TimeBased = 'time_based';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
