<?php

namespace App\Models;

use App\Enums\NumberingDocumentType;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NumberingSequence extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'branch_id',
        'scope_key',
        'document_type',
        'period_key',
        'last_value',
    ];

    protected function casts(): array
    {
        return [
            'document_type' => NumberingDocumentType::class,
            'last_value' => 'integer',
        ];
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }
}
