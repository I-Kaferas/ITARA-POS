<?php

namespace App\Enums;

enum NotificationEvent: string
{
    case NewOrder = 'new_order';
    case Payment = 'payment';
    case LowStock = 'low_stock';
    case Reservation = 'reservation';
    case UnpaidInvoice = 'unpaid_invoice';
    case Approval = 'approval';
    case Anomaly = 'anomaly';
    case Maintenance = 'maintenance';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function title(): string
    {
        return match ($this) {
            self::NewOrder => 'Nouvelle commande',
            self::Payment => 'Paiement',
            self::LowStock => 'Stock faible',
            self::Reservation => 'Réservation',
            self::UnpaidInvoice => 'Facture impayée',
            self::Approval => 'Approbation',
            self::Anomaly => 'Anomalie',
            self::Maintenance => 'Maintenance',
        };
    }

    public function link(): string
    {
        return match ($this) {
            self::NewOrder => '/admin/pos/orders',
            self::Payment => '/admin/sales',
            self::LowStock => '/admin/inventory/alerts',
            self::Reservation => '/admin/pos/reservations',
            self::UnpaidInvoice => '/admin/customers',
            self::Approval => '/admin/purchases/requisitions',
            self::Anomaly => '/admin/organization/devices',
            self::Maintenance => '/admin/hotel/housekeeping',
        };
    }
}
