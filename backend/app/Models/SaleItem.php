<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SaleItem extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_id',
        'product_id',
        'product_variant_id',
        'product_name',
        'product_sku',
        'quantity',
        'unit_price',
        'price_type',
        'catalog_price',
        'tax_rate',
        'line_subtotal',
        'line_tax',
        'line_total',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'unit_price' => 'integer',
            'catalog_price' => 'integer',
            'line_subtotal' => 'integer',
            'line_tax' => 'integer',
            'line_total' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function productVariant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class);
    }

    public function returnItems(): HasMany
    {
        return $this->hasMany(SaleReturnItem::class);
    }

    public function quantityAlreadyReturned(): int
    {
        return (int) SaleReturnItem::query()
            ->where('sale_item_id', $this->id)
            ->whereHas('saleReturn', fn ($query) => $query->where('status', 'completed'))
            ->sum('quantity_returned');
    }

    public function quantityReturnable(): int
    {
        return max(0, $this->quantity - $this->quantityAlreadyReturned());
    }
}
