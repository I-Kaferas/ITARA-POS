<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class InventoryCountItem extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'inventory_count_id',
        'product_id',
        'product_variant_id',
        'sale_unit_id',
        'counted_quantity',
        'entered_quantity',
        'unit_name',
        'unit_volume_ml',
        'remainder_ml',
        'unit_cost',
        'line_value',
        'variance_reason',
        'notes',
        'system_quantity',
    ];

    protected function casts(): array
    {
        return [
            'counted_quantity' => 'integer',
            'entered_quantity' => 'integer',
            'unit_volume_ml' => 'integer',
            'remainder_ml' => 'integer',
            'unit_cost' => 'integer',
            'line_value' => 'integer',
            'system_quantity' => 'integer',
        ];
    }

    public function count(): BelongsTo
    {
        return $this->belongsTo(InventoryCount::class, 'inventory_count_id');
    }

    public function inventoryCount(): BelongsTo
    {
        return $this->belongsTo(InventoryCount::class, 'inventory_count_id');
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function saleUnit(): BelongsTo
    {
        return $this->belongsTo(ProductSaleUnit::class, 'sale_unit_id');
    }
}
