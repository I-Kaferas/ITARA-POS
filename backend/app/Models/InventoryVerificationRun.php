<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class InventoryVerificationRun extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'plan_id',
        'reference',
        'warehouse_id',
        'status',
        'performed_by',
        'analyzed_at',
        'summary',
        'validated_by',
        'validated_at',
    ];

    protected function casts(): array
    {
        return [
            'analyzed_at' => 'datetime',
            'validated_at' => 'datetime',
            'summary' => 'array',
        ];
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(InventoryVerificationPlan::class, 'plan_id');
    }

    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
    }

    public function performedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'performed_by');
    }

    public function validatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'validated_by');
    }

    public function findings(): HasMany
    {
        return $this->hasMany(InventoryVerificationFinding::class, 'run_id');
    }
}
