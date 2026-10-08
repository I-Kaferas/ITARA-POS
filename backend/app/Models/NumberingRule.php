<?php

namespace App\Models;

use App\Enums\NumberingDocumentType;
use App\Enums\NumberingResetPolicy;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NumberingRule extends Model
{
    use BelongsToTenant, HasUuids;

    public const TENANT_SCOPE = 'tenant';

    protected $fillable = [
        'tenant_id',
        'branch_id',
        'scope_key',
        'document_type',
        'prefix',
        'pattern',
        'padding',
        'reset_policy',
        'starting_number',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'document_type' => NumberingDocumentType::class,
            'reset_policy' => NumberingResetPolicy::class,
            'padding' => 'integer',
            'starting_number' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }

    public static function scopeKeyFor(?string $branchId): string
    {
        return $branchId ?: self::TENANT_SCOPE;
    }
}
