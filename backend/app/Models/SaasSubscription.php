<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SaasSubscription extends Model
{
    use HasUuids;

    protected $fillable = [
        'tenant_id',
        'plan_code',
        'status',
        'billing_cycle',
        'trial_ends_on',
        'period_starts_on',
        'period_ends_on',
        'grace_ends_on',
        'pending_plan_code',
        'pending_billing_cycle',
        'suspended_at',
        'cancelled_at',
    ];

    protected function casts(): array
    {
        return [
            'trial_ends_on' => 'date',
            'period_starts_on' => 'date',
            'period_ends_on' => 'date',
            'grace_ends_on' => 'date',
            'suspended_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(SaasPlan::class, 'plan_code', 'code');
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(SaasInvoice::class, 'subscription_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(SaasSubscriptionEvent::class, 'subscription_id');
    }
}
