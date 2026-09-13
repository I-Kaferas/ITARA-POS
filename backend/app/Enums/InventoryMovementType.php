<?php

namespace App\Enums;

enum InventoryMovementType: string
{
    case Purchase = 'PURCHASE';
    case Sale = 'SALE';
    case SaleReturn = 'SALE_RETURN';
    case PurchaseReturn = 'PURCHASE_RETURN';
    case TransferIn = 'TRANSFER_IN';
    case TransferOut = 'TRANSFER_OUT';
    case AdjustmentIn = 'ADJUSTMENT_IN';
    case AdjustmentOut = 'ADJUSTMENT_OUT';
    case Damage = 'DAMAGE';
    case Loss = 'LOSS';
    case Expired = 'EXPIRED';
    case InitialStock = 'INITIAL_STOCK';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    /**
     * Spec ledger label. Opening stock is stored as INITIAL_STOCK and shown as OPENING.
     */
    public function specCode(): string
    {
        return $this === self::InitialStock ? 'OPENING' : $this->value;
    }

    public static function parse(string $value): self
    {
        $normalized = strtoupper(trim($value));

        if ($normalized === 'OPENING') {
            return self::InitialStock;
        }

        return self::from($normalized);
    }

    public function isInbound(): bool
    {
        return match ($this) {
            self::Purchase,
            self::SaleReturn,
            self::TransferIn,
            self::AdjustmentIn,
            self::InitialStock => true,
            default => false,
        };
    }

    public function isOutbound(): bool
    {
        return ! $this->isInbound();
    }

    /** Positive for inbound, negative for outbound. */
    public function signedQuantity(int $absoluteQuantity): int
    {
        if ($absoluteQuantity < 0) {
            throw new \InvalidArgumentException('Quantity must be non-negative.');
        }

        return $this->isInbound() ? $absoluteQuantity : -$absoluteQuantity;
    }

    /** @return list<self> */
    public static function adjustmentTypes(): array
    {
        return [
            self::AdjustmentIn,
            self::AdjustmentOut,
            self::Damage,
            self::Loss,
            self::Expired,
        ];
    }
}
