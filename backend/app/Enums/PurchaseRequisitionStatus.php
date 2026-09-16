<?php

namespace App\Enums;

enum PurchaseRequisitionStatus: string
{
    case Draft = 'draft';
    case Submitted = 'submitted';
    case Approved = 'approved';
    case Rejected = 'rejected';
    case Converted = 'converted';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public function canSubmit(): bool
    {
        return $this === self::Draft;
    }

    public function canApprove(): bool
    {
        return $this === self::Submitted;
    }

    public function canReject(): bool
    {
        return $this === self::Submitted;
    }

    public function canConvert(): bool
    {
        return $this === self::Approved;
    }
}
