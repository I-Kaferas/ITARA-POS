<?php

namespace App\Enums;

enum NumberingDocumentType: string
{
    case Invoice = 'invoice';
    case Pos = 'pos';
    case PurchaseOrder = 'purchase_order';
    case Reservation = 'reservation';
    case Expense = 'expense';
    case Receipt = 'receipt';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function label(): string
    {
        return match ($this) {
            self::Invoice => 'Facture',
            self::Pos => 'Vente POS',
            self::PurchaseOrder => 'Bon de commande',
            self::Reservation => 'Réservation',
            self::Expense => 'Dépense',
            self::Receipt => 'Reçu',
        };
    }
}
