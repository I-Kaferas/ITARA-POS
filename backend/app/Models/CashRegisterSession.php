<?php

namespace App\Models;

use App\Enums\CashRegisterSessionStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CashRegisterSession extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'cash_register_id',
        'opened_by',
        'closed_by',
        'status',
        'opening_balance',
        'sales_total',
        'cash_in_total',
        'cash_out_total',
        'expenses_total',
        'expected_cash',
        'actual_cash',
        'variance',
        'opening_notes',
        'closing_notes',
        'opened_at',
        'closed_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => CashRegisterSessionStatus::class,
            'opening_balance' => 'integer',
            'sales_total' => 'integer',
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
        return $this->status === CashRegisterSessionStatus::Open;
    }

    public function register(): BelongsTo
    {
        return $this->belongsTo(CashRegister::class, 'cash_register_id');
    }

    public function openedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'opened_by');
    }

    public function closedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'closed_by');
    }

    public function movements(): HasMany
    {
        return $this->hasMany(CashMovement::class);
    }
}
