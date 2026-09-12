<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use App\Services\Catalog\PriceService;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class ProductVariant extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'product_id',
        'sku',
        'name',
        'size',
        'color',
        'color_hex',
        'base_price',
        'cost_price',
        'sort_order',
        'is_active',
        'attributes',
    ];

    protected function casts(): array
    {
        return [
            'base_price' => 'integer',
            'cost_price' => 'integer',
            'sort_order' => 'integer',
            'is_active' => 'boolean',
            'attributes' => 'array',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function barcodes(): MorphMany
    {
        return $this->morphMany(Barcode::class, 'barcodeable');
    }

    public function prices(): MorphMany
    {
        return $this->morphMany(Price::class, 'priceable');
    }

    public function primaryBarcode(): ?Barcode
    {
        return $this->barcodes()->where('is_primary', true)->first()
            ?? $this->barcodes()->first();
    }

    public function effectivePrice(?string $priceType = 'retail', ?Store $store = null, int $quantity = 1): int
    {
        return app(PriceService::class)
            ->resolve($this, $store, $priceType ?? 'retail', $quantity)
            ->amount;
    }

    /** @return array<string, mixed> */
    public function toPosSyncArray(?Store $store = null): array
    {
        $priceService = app(PriceService::class);
        $tiers = $priceService->activeTiersForModel($this, $store);
        $options = is_array($this->attributes['options'] ?? null) ? $this->attributes['options'] : [];
        $label = $options !== []
            ? implode(' / ', array_values($options))
            : trim(implode(' / ', array_filter([$this->size, $this->color]))) ?: ($this->name ?? $this->sku);

        return [
            'variant_id' => $this->id,
            'sku' => $this->sku,
            'name' => $this->name ?? $this->product->name,
            'label' => $label,
            'options' => $options,
            'size' => $this->size,
            'color' => $this->color,
            'color_hex' => $this->color_hex,
            'price' => $tiers['retail'] ?? $this->base_price,
            'prices' => $tiers,
            'barcode' => $this->primaryBarcode()?->barcode,
            'barcodes' => $this->barcodes->map(fn ($b) => [
                'barcode' => $b->barcode,
                'type' => $b->type,
                'is_primary' => $b->is_primary,
            ])->values()->all(),
            'is_active' => $this->is_active,
        ];
    }
}
