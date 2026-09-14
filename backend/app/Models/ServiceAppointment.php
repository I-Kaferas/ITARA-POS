<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ServiceAppointment extends Model
{
    use BelongsToTenant, HasUuids;

    public const STATUSES = ['booked', 'assigned', 'completed', 'paid'];

    protected $fillable = [
        'tenant_id',
        'store_id',
        'service_offering_id',
        'customer_name',
        'employee_id',
        'scheduled_at',
        'status',
        'completed_at',
        'completed_by',
        'completion_notes',
        'paid_at',
        'payment_method',
        'paid_amount',
        'sale_id',
    ];

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'datetime',
            'completed_at' => 'datetime',
            'paid_at' => 'datetime',
            'paid_amount' => 'integer',
        ];
    }

    public function offering(): BelongsTo
    {
        return $this->belongsTo(ServiceOffering::class, 'service_offering_id');
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'employee_id');
    }
}
