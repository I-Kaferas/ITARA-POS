<?php

namespace App\Enums;

enum PurchaseProformaStatus: string
{
    case Draft = 'draft';
    case Sent = 'sent';
    case UnderReview = 'under_review';
    case Approved = 'approved';
    case Rejected = 'rejected';
    case Expired = 'expired';
    case Converted = 'converted';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function canSend(): bool
    {
        return $this === self::Draft;
    }

    public function canReview(): bool
    {
        return $this === self::Sent;
    }

    public function canApprove(): bool
    {
        return $this === self::UnderReview;
    }

    public function canReject(): bool
    {
        return in_array($this, [self::Sent, self::UnderReview], true);
    }

    public function canConvert(): bool
    {
        return $this === self::Approved;
    }

    public function isClosed(): bool
    {
        return in_array($this, [self::Rejected, self::Expired, self::Converted], true);
    }
}
