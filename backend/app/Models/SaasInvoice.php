<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SaasInvoice extends Model
{
    use HasUuids;

    protected $fillable = [
        'tenant_id',
        'subscription_id',
        'number',
        'kind',
        'status',
        'plan_code',
        'billing_cycle',
        'amount',
        'currency_code',
        'period_starts_on',
        'period_ends_on',
        'issued_on',
        'due_on',
        'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'period_starts_on' => 'date',
            'period_ends_on' => 'date',
            'issued_on' => 'date',
            'due_on' => 'date',
            'paid_at' => 'datetime',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(SaasSubscription::class, 'subscription_id');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(SaasPayment::class, 'invoice_id');
    }
}
