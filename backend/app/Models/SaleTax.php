<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleTax extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_id',
        'sale_item_id',
        'tax_id',
        'tax_name',
        'tax_rate',
        'taxable_amount',
        'tax_amount',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'tax_rate' => 'decimal:4',
            'taxable_amount' => 'integer',
            'tax_amount' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function saleItem(): BelongsTo
    {
        return $this->belongsTo(SaleItem::class);
    }
}
