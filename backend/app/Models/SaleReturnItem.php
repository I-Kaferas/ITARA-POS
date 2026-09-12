<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleReturnItem extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_return_id',
        'sale_item_id',
        'product_id',
        'product_variant_id',
        'product_name',
        'product_sku',
        'quantity_returned',
        'unit_price',
        'tax_rate',
        'line_subtotal',
        'line_tax',
        'line_total',
        'batch_id',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'quantity_returned' => 'integer',
            'unit_price' => 'integer',
            'line_subtotal' => 'integer',
            'line_tax' => 'integer',
            'line_total' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function saleReturn(): BelongsTo
    {
        return $this->belongsTo(SaleReturn::class);
    }

    public function saleItem(): BelongsTo
    {
        return $this->belongsTo(SaleItem::class);
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
