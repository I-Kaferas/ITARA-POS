<?php

namespace App\Models;

use App\Enums\PartyKind;
use App\Models\Concerns\BelongsToTenant;
use App\Models\Concerns\SyncsWithParty;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class CrmAccount extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes, SyncsWithParty;

    protected $fillable = [
        'tenant_id',
        'party_id',
        'name',
        'legal_name',
        'email',
        'phone',
        'website',
        'tax_id',
        'industry',
        'address',
    ];

    protected function casts(): array
    {
        return [
            'address' => 'array',
        ];
    }

    protected function partyKind(): PartyKind
    {
        return PartyKind::Organization;
    }

    public function party(): BelongsTo
    {
        return $this->belongsTo(Party::class);
    }

    public function contacts(): HasMany
    {
        return $this->hasMany(Customer::class, 'crm_account_id');
    }

    public function opportunities(): HasMany
    {
        return $this->hasMany(CrmOpportunity::class, 'crm_account_id');
    }
}
