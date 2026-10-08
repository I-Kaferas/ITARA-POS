<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CurrencyExchangeRate extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'currency_id',
        'currency_code',
        'rate',
        'previous_rate',
        'base_currency_code',
        'effective_at',
        'changed_by',
        'source',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'rate' => 'decimal:8',
            'previous_rate' => 'decimal:8',
            'effective_at' => 'datetime',
        ];
    }

    public function currency(): BelongsTo
    {
        return $this->belongsTo(Currency::class);
    }

    public function changedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
