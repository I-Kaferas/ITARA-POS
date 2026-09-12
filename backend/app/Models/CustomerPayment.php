<?php

namespace App\Models;

use App\Enums\CustomerPaymentMethod;
use App\Enums\CustomerPaymentStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class CustomerPayment extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'customer_id',
        'payment_number',
        'amount',
        'payment_method',
        'reference',
        'notes',
        'status',
        'paid_at',
        'recorded_by',
        'allocations',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'payment_method' => CustomerPaymentMethod::class,
            'status' => CustomerPaymentStatus::class,
            'paid_at' => 'datetime',
            'allocations' => 'array',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function recordedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(CustomerTransaction::class);
    }
}
