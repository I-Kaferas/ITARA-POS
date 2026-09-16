<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PurchaseProformaItem extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'purchase_proforma_id',
        'product_id',
        'product_variant_id',
        'quantity',
        'unit_cost',
        'tax_rate',
        'line_total',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'unit_cost' => 'integer',
            'tax_rate' => 'decimal:4',
            'line_total' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function proforma(): BelongsTo
    {
        return $this->belongsTo(PurchaseProforma::class, 'purchase_proforma_id');
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function productVariant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class);
    }
}
