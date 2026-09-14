<?php

namespace App\Enums;

enum SaleDiscountType: string
{
    case Line = 'line';
    case Promotion = 'promotion';
    case Global = 'global';
}
