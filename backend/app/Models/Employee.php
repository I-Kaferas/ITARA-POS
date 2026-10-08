<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Employee extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'party_id',
        'user_id',
        'code',
        'job_title',
        'department',
        'hired_on',
        'terminated_on',
        'metadata',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'hired_on' => 'date',
            'terminated_on' => 'date',
            'metadata' => 'array',
            'is_active' => 'boolean',
        ];
    }

    public function party(): BelongsTo
    {
        return $this->belongsTo(Party::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
