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
    case CashAdjustment = 'cash_adjustment';
    case CashCount = 'cash_count';
    case Expense = 'expense';
}
