<?php

namespace App\Enums;

enum CashMovementType: string
{
    case OpeningBalance = 'opening_balance';
    case Sale = 'sale';
    case Refund = 'refund';
    case Discount = 'discount';
    case CashIn = 'cash_in';
    case CashOut = 'cash_out';
    case Expense = 'expense';
}
