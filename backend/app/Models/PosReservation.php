<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PosReservation extends Model
{
    use BelongsToTenant, HasUuids;

    public const STATUSES = [
        'pending',
        'confirmed',
        'seated',
        'completed',
        'cancelled',
        'no_show',
    ];

    protected $fillable = [
        'tenant_id',
        'store_id',
        'customer_id',
        'reference',
        'guest_name',
        'phone',
        'party_size',
        'reserved_at',
        'table_label',
        'status',
        'notes',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'party_size' => 'integer',
            'reserved_at' => 'datetime',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
