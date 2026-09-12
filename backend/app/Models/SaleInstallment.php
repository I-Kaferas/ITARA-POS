<?php

namespace App\Models;

use App\Enums\SaleInstallmentStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleInstallment extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_id',
        'installment_number',
        'amount',
        'paid_amount',
        'due_date',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'installment_number' => 'integer',
            'amount' => 'integer',
            'paid_amount' => 'integer',
            'due_date' => 'date',
            'status' => SaleInstallmentStatus::class,
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function outstandingAmount(): int
    {
        return max(0, $this->amount - $this->paid_amount);
    }

    public function isOverdue(): bool
    {
        return $this->due_date->isPast() && $this->outstandingAmount() > 0;
    }

    public function refreshStatus(): void
    {
        if ($this->outstandingAmount() <= 0) {
            $this->status = SaleInstallmentStatus::Paid;

            return;
        }

        $this->status = $this->isOverdue()
            ? SaleInstallmentStatus::Overdue
            : SaleInstallmentStatus::Pending;
    }
}
