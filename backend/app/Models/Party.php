<?php

namespace App\Models;

use App\Enums\PartyKind;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Party extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'kind',
        'display_name',
        'legal_name',
        'code',
        'email',
        'phone',
        'tax_id',
        'address',
        'notes',
        'metadata',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'kind' => PartyKind::class,
            'address' => 'array',
            'metadata' => 'array',
            'is_active' => 'boolean',
        ];
    }

    public function customer(): HasOne
    {
        return $this->hasOne(Customer::class);
    }

    public function supplier(): HasOne
    {
        return $this->hasOne(Supplier::class);
    }

    public function employee(): HasOne
    {
        return $this->hasOne(Employee::class);
    }

    public function user(): HasOne
    {
        return $this->hasOne(User::class);
    }

    public function organization(): HasOne
    {
        return $this->hasOne(Organization::class);
    }

    public function crmAccount(): HasOne
    {
        return $this->hasOne(CrmAccount::class);
    }

    public function contexts(): HasMany
    {
        return $this->hasMany(PartyContextLink::class);
    }

    public function documents(): HasMany
    {
        return $this->hasMany(BusinessDocument::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class)->orderByDesc('date');
    }

    /** @return list<string> */
    public function roleNames(): array
    {
        $roles = [];

        if ($this->customer()->exists()) {
            $roles[] = 'customer';
        }
        if ($this->supplier()->exists()) {
            $roles[] = 'supplier';
        }
        if ($this->employee()->exists()) {
            $roles[] = 'employee';
        }
        if ($this->user()->exists()) {
            $roles[] = 'user';
        }
        if ($this->organization()->exists()) {
            $roles[] = 'organization';
        }
        if ($this->crmAccount()->exists()) {
            $roles[] = 'crm_account';
        }

        return $roles;
    }
}
