<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use App\Services\Catalog\PriceService;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\Pivot;

class StoreProduct extends Pivot
{
    use BelongsToTenant, HasUuids;

    public $incrementing = false;

    protected $table = 'store_products';

    protected $fillable = [
        'tenant_id',
        'store_id',
        'product_id',
        'is_available',
        'price_override',
        'imported_at',
        'imported_by',
    ];

    protected function casts(): array
    {
        return [
            'is_available' => 'boolean',
            'price_override' => 'integer',
            'imported_at' => 'datetime',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function importedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'imported_by');
    }

    public function effectivePrice(string $priceType = 'retail', int $quantity = 1): int
    {
        return app(PriceService::class)
            ->resolveForStoreProduct($this, $priceType, $quantity)
            ->amount;
    }

    /**
     * Full product payload for POS import/sync including CDN image gallery.
     *
     * @return array<string, mixed>
     */
    public function toPosSyncArray(): array
    {
        $product = $this->relationLoaded('product')
            ? $this->product
            : $this->product()->with([
                'images' => fn ($query) => $query->ordered(),
                'tax',
                'unitModel',
                'prices',
                'variants' => fn ($q) => $q->where('is_active', true)->with('prices'),
                'bundleItems',
                'barcodes',
            ])->first();

        $store = $this->relationLoaded('store')
            ? $this->store
            : $this->store()->first();

        $priceService = app(PriceService::class);
        $resolved = $priceService->resolveForStoreProduct($this, 'retail');
        $tiers = $priceService->activeTiersForModel($product, $store);
        $primaryImage = $product->primaryImage();

        return [
            'store_product_id' => $this->id,
            'store_id' => $this->store_id,
            'product_id' => $product->id,
            'category_id' => $product->category_id,
            'sku' => $product->sku,
            'name' => $product->name,
            'description' => $product->description,
            'barcode' => $product->primaryBarcode()?->barcode ?? $product->barcode,
            'barcodes' => $product->barcodes->map(fn (Barcode $b) => [
                'barcode' => $b->barcode,
                'type' => $b->type,
                'is_primary' => $b->is_primary,
            ])->values()->all(),
            'unit' => $product->unitModel?->code ?? $product->unit,
            'product_type' => $product->product_type,
            'requires_stock' => $product->requiresStock(),
            'is_weighable' => $product->isWeighable(),
            'is_serialized' => $product->is_serialized,
            'track_batch' => $product->track_batch,
            'track_expiration' => $product->track_expiration,
            'tax_rate' => $product->tax?->rate,
            'price' => $resolved->amount,
            'prices' => $tiers,
            'default_price_type' => 'retail',
            'is_available' => $this->is_available,
            'primary_image_cdn_url' => $primaryImage?->cdn_url,
            'images' => $product->imageGalleryForPos(),
            'variants' => $product->isVariantProduct()
                ? $product->variants->where('is_active', true)->map->toPosSyncArray($store)->values()->all()
                : [],
            'bundle_items' => $product->isBundle()
                ? $product->bundleItems->map(fn ($item) => [
                    'component_product_id' => $item->component_product_id,
                    'component_variant_id' => $item->component_variant_id,
                    'quantity' => (float) $item->quantity,
                ])->all()
                : [],
        ];
    }
}
