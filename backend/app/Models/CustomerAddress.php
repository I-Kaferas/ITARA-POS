<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class CustomerAddress extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'customer_id',
        'label',
        'line1',
        'line2',
        'city',
        'state',
        'postal_code',
        'country_code',
        'is_primary',
        'is_billing',
        'is_shipping',
    ];

    protected function casts(): array
    {
        return [
            'is_primary' => 'boolean',
            'is_billing' => 'boolean',
            'is_shipping' => 'boolean',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}
