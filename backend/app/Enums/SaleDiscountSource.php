<?php

namespace App\Enums;

enum SaleDiscountSource: string
{
    case Manual = 'manual';
    case Promotion = 'promotion';
}
