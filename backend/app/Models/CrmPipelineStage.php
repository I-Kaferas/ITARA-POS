<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CrmPipelineStage extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'name',
        'position',
        'probability',
        'is_won',
        'is_lost',
    ];

    protected function casts(): array
    {
        return [
            'position' => 'integer',
            'probability' => 'integer',
            'is_won' => 'boolean',
            'is_lost' => 'boolean',
        ];
    }

    public function opportunities(): HasMany
    {
        return $this->hasMany(CrmOpportunity::class, 'stage_id');
    }
}
