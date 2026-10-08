<?php

namespace App\Models;

use App\Enums\BusinessDocumentKind;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class BusinessDocument extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'party_id',
        'location_id',
        'kind',
        'number',
        'status',
        'source_type',
        'source_id',
        'payload',
        'issued_at',
    ];

    protected function casts(): array
    {
        return [
            'kind' => BusinessDocumentKind::class,
            'payload' => 'array',
            'issued_at' => 'datetime',
        ];
    }

    public function party(): BelongsTo
    {
        return $this->belongsTo(Party::class);
    }

    public function location(): BelongsTo
    {
        return $this->belongsTo(Location::class);
    }

    public function source(): MorphTo
    {
        return $this->morphTo();
    }
}
