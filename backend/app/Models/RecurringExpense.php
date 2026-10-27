<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RecurringExpense extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'branch_id',
        'store_id',
        'expense_category_id',
        'cash_register_id',
        'user_id',
        'name',
        'fund_source',
        'amount',
        'currency_code',
        'frequency',
        'next_due_on',
        'starts_on',
        'ends_on',
        'notes',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'next_due_on' => 'date',
            'starts_on' => 'date',
            'ends_on' => 'date',
            'is_active' => 'boolean',
        ];
    }

    public function expenseCategory(): BelongsTo
    {
        return $this->belongsTo(ExpenseCategory::class);
    }

    public function cashRegister(): BelongsTo
    {
        return $this->belongsTo(CashRegister::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
