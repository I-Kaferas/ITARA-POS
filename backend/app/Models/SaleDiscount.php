<?php

namespace App\Models;

use App\Enums\SaleDiscountSource;
use App\Enums\SaleDiscountType;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleDiscount extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_id',
        'sale_item_id',
        'promotion_id',
        'discount_type',
        'source',
        'label',
        'amount',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'discount_type' => SaleDiscountType::class,
            'source' => SaleDiscountSource::class,
            'amount' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function promotion(): BelongsTo
    {
        return $this->belongsTo(Promotion::class);
    }
}
