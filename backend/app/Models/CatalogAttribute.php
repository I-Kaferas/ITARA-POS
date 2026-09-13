<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class CatalogAttribute extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'name',
        'code',
        'values',
        'sort_order',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'values' => 'array',
            'sort_order' => 'integer',
            'is_active' => 'boolean',
        ];
    }
}
