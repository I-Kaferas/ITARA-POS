<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PurchaseOrderItem extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'purchase_order_id',
        'product_id',
        'product_variant_id',
        'quantity_ordered',
        'quantity_received',
        'unit_cost',
        'tax_rate',
        'line_total',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'quantity_ordered' => 'integer',
            'quantity_received' => 'integer',
            'unit_cost' => 'integer',
            'tax_rate' => 'decimal:4',
            'line_total' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function purchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function productVariant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class);
    }

    public function receiptItems(): HasMany
    {
        return $this->hasMany(GoodsReceiptItem::class);
    }

    public function quantityRemaining(): int
    {
        return max(0, $this->quantity_ordered - $this->quantity_received);
    }

    public static function computeLineTotal(int $quantity, int $unitCost, float $taxRate = 0): int
    {
        $base = $quantity * $unitCost;

        return (int) round($base * (1 + ($taxRate / 100)));
    }
}
