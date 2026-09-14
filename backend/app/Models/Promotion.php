<?php

namespace App\Models;

use App\Enums\PromotionType;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Promotion extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'category_id',
        'name',
        'code',
        'type',
        'description',
        'starts_at',
        'ends_at',
        'min_quantity',
        'max_uses',
        'uses_count',
        'priority',
        'discount_percent',
        'discount_amount',
        'buy_quantity',
        'get_quantity',
        'bundle_price',
        'schedule',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'type' => PromotionType::class,
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'min_quantity' => 'integer',
            'max_uses' => 'integer',
            'uses_count' => 'integer',
            'priority' => 'integer',
            'discount_percent' => 'decimal:2',
            'discount_amount' => 'integer',
            'buy_quantity' => 'integer',
            'get_quantity' => 'integer',
            'bundle_price' => 'integer',
            'schedule' => 'array',
            'is_active' => 'boolean',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(PromotionItem::class);
    }

    public function customers(): HasMany
    {
        return $this->hasMany(PromotionCustomer::class);
    }
}
