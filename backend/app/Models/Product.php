<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use App\Services\Catalog\PriceService;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Validation\ValidationException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'catalog_id',
        'category_id',
        'product_type',
        'brand_id',
        'unit_id',
        'tax_id',
        'sku',
        'name',
        'description',
        'barcode',
        'unit',
        'bottle_volume_ml',
        'base_price',
        'cost_price',
        'is_active',
        'is_serialized',
        'track_batch',
        'track_expiration',
        'expiration_days',
        'low_stock_threshold',
        'inventory_class',
        'count_frequency',
        'last_counted_at',
        'next_count_at',
        'metadata',
        'accompaniment_enabled',
    ];

    protected function casts(): array
    {
        return [
            'base_price' => 'integer',
            'cost_price' => 'integer',
            'is_active' => 'boolean',
            'is_serialized' => 'boolean',
            'track_batch' => 'boolean',
            'track_expiration' => 'boolean',
            'expiration_days' => 'integer',
            'low_stock_threshold' => 'integer',
            'last_counted_at' => 'date',
            'next_count_at' => 'date',
            'bottle_volume_ml' => 'integer',
            'metadata' => 'array',
            'accompaniment_enabled' => 'boolean',
        ];
    }

    public function catalog(): BelongsTo
    {
        return $this->belongsTo(Catalog::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function brand(): BelongsTo
    {
        return $this->belongsTo(Brand::class);
    }

    public function unitModel(): BelongsTo
    {
        return $this->belongsTo(Unit::class, 'unit_id');
    }

    public function tax(): BelongsTo
    {
        return $this->belongsTo(Tax::class);
    }

    public function variants(): HasMany
    {
        return $this->hasMany(ProductVariant::class)->orderBy('sort_order');
    }

    public function saleUnits(): HasMany
    {
        return $this->hasMany(ProductSaleUnit::class)->orderBy('sort_order');
    }

    public function tracksVolume(): bool
    {
        return (int) $this->bottle_volume_ml > 0 && $this->saleUnits()->exists();
    }

    public function bundleItems(): HasMany
    {
        return $this->hasMany(ProductBundleItem::class, 'bundle_product_id')->orderBy('sort_order');
    }

    public function barcodes(): MorphMany
    {
        return $this->morphMany(Barcode::class, 'barcodeable');
    }

    public function prices(): MorphMany
    {
        return $this->morphMany(Price::class, 'priceable');
    }

    public function storeProducts(): HasMany
    {
        return $this->hasMany(StoreProduct::class);
    }

    public function stores(): BelongsToMany
    {
        return $this->belongsToMany(Store::class, 'store_products')
            ->using(StoreProduct::class)
            ->withPivot(['is_available', 'price_override', 'imported_at', 'imported_by'])
            ->withTimestamps();
    }

    public function images(): HasMany
    {
        return $this->hasMany(ProductImage::class)->ordered();
    }

    public function batches(): HasMany
    {
        return $this->hasMany(Batch::class);
    }

    public function serialNumbers(): HasMany
    {
        return $this->hasMany(SerialNumber::class);
    }

    public function suppliers(): BelongsToMany
    {
        return $this->belongsToMany(Supplier::class, 'product_supplier')
            ->withPivot(['supplier_sku', 'cost_price'])
            ->withTimestamps();
    }

    public function stockBalances(): HasMany
    {
        return $this->hasMany(StockBalance::class);
    }

    public function inventoryMovements(): HasMany
    {
        return $this->hasMany(InventoryMovement::class);
    }

    public function inventoryAlerts(): HasMany
    {
        return $this->hasMany(InventoryAlert::class);
    }

    public function accompanimentLinks(): HasMany
    {
        return $this->hasMany(ProductAccompanimentLink::class, 'product_id')->orderBy('sort_order');
    }

    public function accompanimentProducts(): BelongsToMany
    {
        return $this->belongsToMany(
            Product::class,
            'product_accompaniment_links',
            'product_id',
            'accompaniment_product_id',
        )->withPivot(['id', 'sort_order'])->orderByPivot('sort_order');
    }

    public function tracksBatches(): bool
    {
        return $this->track_batch || $this->product_type === 'batch';
    }

    public function tracksExpiration(): bool
    {
        return $this->track_expiration;
    }

    public function effectiveLowStockThreshold(): ?int
    {
        if ($this->low_stock_threshold === 0) {
            return null;
        }

        return $this->low_stock_threshold
            ?? (int) config('inventory.default_low_stock_threshold', 10);
    }

    public function allocationStrategy(): \App\Enums\BatchAllocationStrategy
    {
        if ($this->tracksExpiration()) {
            return \App\Enums\BatchAllocationStrategy::Fefo;
        }

        return match (strtoupper((string) config('inventory.default_allocation_strategy', 'fifo'))) {
            'FEFO' => \App\Enums\BatchAllocationStrategy::Fefo,
            default => \App\Enums\BatchAllocationStrategy::Fifo,
        };
    }

    public function primaryImage(): ?ProductImage
    {
        return $this->images()->where('is_primary', true)->first()
            ?? $this->images()->ordered()->first();
    }

    public function primaryBarcode(): ?Barcode
    {
        return $this->barcodes()->where('is_primary', true)->first()
            ?? $this->barcodes()->first();
    }

    /** @return list<string> */
    public static function nonStockableTypes(): array
    {
        return ['service', 'digital'];
    }

    public function isService(): bool
    {
        return $this->product_type === 'service';
    }

    public function isDigital(): bool
    {
        return $this->product_type === 'digital';
    }

    public function requiresStock(): bool
    {
        return ! in_array($this->product_type, self::nonStockableTypes(), true);
    }

    public function assertStockable(): void
    {
        if ($this->requiresStock()) {
            return;
        }

        throw ValidationException::withMessages([
            'product_id' => ["{$this->name} est un service et n'est pas stockable."],
        ]);
    }

    public function isBundle(): bool
    {
        return $this->product_type === 'bundle';
    }

    public function isVariantProduct(): bool
    {
        return $this->product_type === 'variant';
    }

    public function isWeighable(): bool
    {
        return $this->unitModel?->is_fractional === true;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function imageGalleryForPos(): array
    {
        return $this->images->map->toPosSyncArray()->values()->all();
    }

    public function effectivePrice(?string $priceType = 'retail', ?Store $store = null, int $quantity = 1): int
    {
        return app(PriceService::class)
            ->resolve($this, $store, $priceType ?? 'retail', $quantity)
            ->amount;
    }

    /**
     * @param  array{category_id?: ?string, brand_id?: ?string, unit_id?: ?string, attributes?: list<array<string, mixed>>|null}  $taxonomy
     */
    public function importToStore(
        Store $store,
        ?int $priceOverride = null,
        bool $isAvailable = true,
        ?string $importedBy = null,
        array $taxonomy = [],
    ): StoreProduct {
        $payload = [
            'tenant_id' => $this->tenant_id,
            'is_available' => $isAvailable,
            'price_override' => $priceOverride,
            'imported_at' => now(),
            'imported_by' => $importedBy,
        ];

        foreach (['category_id', 'brand_id', 'unit_id', 'attributes'] as $key) {
            if (array_key_exists($key, $taxonomy)) {
                $payload[$key] = $taxonomy[$key] ?: null;
            }
        }

        return StoreProduct::query()->updateOrCreate(
            [
                'store_id' => $store->id,
                'product_id' => $this->id,
            ],
            $payload,
        );
    }

    public function priceForStore(Store $store): int
    {
        $storeProduct = $this->storeProducts()
            ->where('store_id', $store->id)
            ->first();

        if ($storeProduct?->price_override !== null) {
            return $storeProduct->price_override;
        }

        return $this->effectivePrice('base', $store);
    }

    public function isImportedInStore(Store $store): bool
    {
        return $this->storeProducts()
            ->where('store_id', $store->id)
            ->exists();
    }

    /** @return list<string> */
    public static function productTypes(): array
    {
        return array_keys(config('product_types.types', []));
    }
}
