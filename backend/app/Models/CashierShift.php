<?php

namespace App\Models;

use App\Enums\CashierShiftStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CashierShift extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'cashier_id',
        'cash_register_id',
        'cash_register_session_id',
        'status',
        'opening_balance',
        'sales_total',
        'refunds_total',
        'discounts_total',
        'cash_in_total',
        'cash_out_total',
        'expenses_total',
        'expected_cash',
        'actual_cash',
        'variance',
        'variance_reason',
        'opening_notes',
        'closing_notes',
        'opened_at',
        'closed_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => CashierShiftStatus::class,
            'opening_balance' => 'integer',
            'sales_total' => 'integer',
            'refunds_total' => 'integer',
            'discounts_total' => 'integer',
            'cash_in_total' => 'integer',
            'cash_out_total' => 'integer',
            'expenses_total' => 'integer',
            'expected_cash' => 'integer',
            'actual_cash' => 'integer',
            'variance' => 'integer',
            'opened_at' => 'datetime',
            'closed_at' => 'datetime',
        ];
    }

    public function isOpen(): bool
    {
        return $this->status === CashierShiftStatus::Open;
    }

    public function movements(): HasMany
    {
        return $this->hasMany(CashMovement::class);
    }

    public function cashier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }

    public function cashRegister(): BelongsTo
    {
        return $this->belongsTo(CashRegister::class);
    }

    public function registerSession(): BelongsTo
    {
        return $this->belongsTo(CashRegisterSession::class, 'cash_register_session_id');
    }
}
