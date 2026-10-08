<?php

namespace App\Models;

use App\Enums\TaxComputationType;
use App\Enums\TaxKind;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Tax extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'name',
        'code',
        'kind',
        'type',
        'rate',
        'priority',
        'country',
        'region',
        'is_inclusive',
        'is_compound',
        'is_active',
        'description',
    ];

    protected function casts(): array
    {
        return [
            'kind' => TaxKind::class,
            'type' => TaxComputationType::class,
            'rate' => 'decimal:4',
            'priority' => 'integer',
            'is_inclusive' => 'boolean',
            'is_compound' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function groups(): BelongsToMany
    {
        return $this->belongsToMany(TaxGroup::class, 'tax_group_tax')
            ->withPivot(['id', 'sort_order'])
            ->withTimestamps()
            ->orderByPivot('sort_order');
    }

    public function rules(): HasMany
    {
        return $this->hasMany(TaxRule::class);
    }
}
