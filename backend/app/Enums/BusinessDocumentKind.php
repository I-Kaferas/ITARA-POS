<?php

namespace App\Enums;

enum BusinessDocumentKind: string
{
    case Invoice = 'invoice';
    case Receipt = 'receipt';
    case CreditNote = 'credit_note';
    case PurchaseOrder = 'purchase_order';
    case GoodsReceipt = 'goods_receipt';
    case Reservation = 'reservation';
    case Contract = 'contract';
    case Other = 'other';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
