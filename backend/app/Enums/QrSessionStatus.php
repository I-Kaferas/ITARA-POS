<?php

namespace App\Enums;

enum QrSessionStatus: string
{
    case Open = 'open';
    case Closed = 'closed';
}
