<?php

namespace App\Enums;

enum CartDiscountType: string
{
    case Fixed = 'fixed';
    case Percent = 'percent';
}
