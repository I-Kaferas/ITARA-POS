<?php

namespace App\Enums;

enum AccountingEntryType: string
{
    case PurchaseReceiptInventory = 'purchase_receipt_inventory';
    case PurchaseReceiptPayable = 'purchase_receipt_payable';
    case SaleRevenue = 'sale_revenue';
    case SaleCash = 'sale_cash';
    case SaleTax = 'sale_tax';
    case SaleCogs = 'sale_cogs';
    case SaleInventory = 'sale_inventory';
    case SaleReturnRevenue = 'sale_return_revenue';
    case SaleReturnCash = 'sale_return_cash';
    case SaleReturnTax = 'sale_return_tax';
    case SaleReturnCogs = 'sale_return_cogs';
    case SaleReturnInventory = 'sale_return_inventory';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
