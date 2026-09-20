<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Catalog extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'company_id',
        'store_id',
        'name',
        'description',
        'is_default',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_default' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function categories(): HasMany
    {
        return $this->hasMany(Category::class);
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    /**
     * Import one or more catalog products into a store.
     *
     * @param  list<Product>|Product  $products
     * @return list<StoreProduct>
     */
    public function importToStore(Store $store, Product|array $products, ?int $importedBy = null): array
    {
        $products = is_array($products) ? $products : [$products];

        $imported = [];

        foreach ($products as $product) {
            if ($product->catalog_id !== $this->id) {
                continue;
            }

            $imported[] = $product->importToStore($store, importedBy: $importedBy);
        }

        return $imported;
    }
}
