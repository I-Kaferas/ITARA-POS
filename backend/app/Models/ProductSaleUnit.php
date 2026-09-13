<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductSaleUnit extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'product_id',
        'name',
        'code',
        'volume_ml',
        'price',
        'is_base',
        'sort_order',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'volume_ml' => 'integer',
            'price' => 'integer',
            'is_base' => 'boolean',
            'sort_order' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    /**
     * @return array<string, mixed>
     */
    public function toPosArray(int $bottleVolumeMl = 0): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'code' => $this->code,
            'volume_ml' => (int) $this->volume_ml,
            'price' => (int) $this->price,
            'is_base' => (bool) $this->is_base,
            'is_active' => (bool) $this->is_active,
            'sort_order' => (int) $this->sort_order,
            'share' => $bottleVolumeMl > 0 ? round(((int) $this->volume_ml) / $bottleVolumeMl, 4) : null,
        ];
    }
}
