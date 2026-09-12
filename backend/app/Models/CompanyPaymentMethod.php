<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CompanyPaymentMethod extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'company_id',
        'code',
        'label',
        'label_fr',
        'is_enabled',
        'available_on_pos',
        'sort_order',
        'config',
    ];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'boolean',
            'available_on_pos' => 'boolean',
            'sort_order' => 'integer',
            'config' => 'array',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    /** @return array<string, mixed> */
    public function toPosArray(): array
    {
        $enum = \App\Enums\SalePaymentMethod::tryFrom($this->code);

        return [
            'id' => $this->id,
            'value' => $this->code,
            'code' => $this->code,
            'label' => $this->label,
            'label_fr' => $this->label_fr ?? $this->label,
            'provider' => config("payments.methods.{$this->code}.provider", $this->code),
            'requires_customer' => $enum?->requiresCustomer() ?? false,
            'supports_change' => (bool) config("payments.methods.{$this->code}.supports_change", false),
            'is_enabled' => $this->is_enabled,
            'available_on_pos' => $this->available_on_pos,
            'sort_order' => $this->sort_order,
            'config' => $this->config ?? [],
        ];
    }
}
