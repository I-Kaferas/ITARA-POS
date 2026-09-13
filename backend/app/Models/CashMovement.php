<?php

namespace App\Models;

use App\Enums\CashMovementType;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CashMovement extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'cash_register_id',
        'cash_register_session_id',
        'cashier_shift_id',
        'movement_type',
        'amount',
        'reference_type',
        'reference_id',
        'reference',
        'description',
        'performed_by',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'movement_type' => CashMovementType::class,
            'amount' => 'integer',
            'occurred_at' => 'datetime',
        ];
    }

    public function signedAmount(): int
    {
        return match ($this->movement_type) {
            CashMovementType::CashOut, CashMovementType::Expense, CashMovementType::Refund => -$this->amount,
            default => $this->amount,
        };
    }

    public function register(): BelongsTo
    {
        return $this->belongsTo(CashRegister::class, 'cash_register_id');
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(CashRegisterSession::class, 'cash_register_session_id');
    }

    public function performedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'performed_by');
    }
}
