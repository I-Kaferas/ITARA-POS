<?php

namespace App\Models;

use App\Enums\PartyContext;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartyContextLink extends Model
{
    use BelongsToTenant, HasUuids;

    protected $table = 'party_contexts';

    protected $fillable = [
        'tenant_id',
        'party_id',
        'context',
        'label',
        'metadata',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'context' => PartyContext::class,
            'metadata' => 'array',
            'is_active' => 'boolean',
        ];
    }

    public function party(): BelongsTo
    {
        return $this->belongsTo(Party::class);
    }
}
