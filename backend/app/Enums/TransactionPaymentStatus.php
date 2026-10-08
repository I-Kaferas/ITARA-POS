<?php

namespace App\Enums;

enum TransactionPaymentStatus: string
{
    case Unpaid = 'unpaid';
    case Paid = 'paid';
    case Partial = 'partial';
    case OnCredit = 'on_credit';
    case NotApplicable = 'not_applicable';

    public static function fromAmounts(int $total, int $paidAmount): self
    {
        if ($total <= 0) {
            return self::Paid;
        }

        if ($paidAmount >= $total) {
            return self::Paid;
        }

        if ($paidAmount > 0) {
            return self::Partial;
        }

        return self::OnCredit;
    }

    public static function fromSalePaymentStatus(SalePaymentStatus $status): self
    {
        return match ($status) {
            SalePaymentStatus::Unpaid => self::Unpaid,
            SalePaymentStatus::Paid => self::Paid,
            SalePaymentStatus::Partial => self::Partial,
            SalePaymentStatus::OnCredit => self::OnCredit,
        };
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
