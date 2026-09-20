<?php

use App\Models\Brand;
use App\Models\Catalog;
use App\Models\CatalogAttribute;
use App\Models\Category;
use App\Models\Store;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Categories / brands / units / attributes are store-specific.
 * The product catalog stays company-shared (one catalog, many stores via store_products).
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->ensureStoreColumn('brands');
        $this->ensureStoreColumn('catalog_attributes');

        if (! Schema::hasColumn('categories', 'store_id')) {
            Schema::table('categories', function (Blueprint $table) {
                $table->foreignUuid('store_id')
                    ->nullable()
                    ->after('catalog_id')
                    ->constrained('stores')
                    ->cascadeOnDelete();
                $table->index(['tenant_id', 'store_id', 'is_active']);
            });
        }

        $this->dropUniqueIfColumns('categories', ['catalog_id', 'slug']);
        $this->dropUniqueIfColumns('categories', ['tenant_id', 'catalog_id', 'slug']);
        $this->dropUniqueIfColumns('brands', ['tenant_id', 'slug']);
        $this->dropUniqueIfColumns('catalog_attributes', ['tenant_id', 'code']);
        $this->ensureUnique('categories', 'categories_catalog_id_store_id_slug_unique', ['catalog_id', 'store_id', 'slug']);
        $this->ensureUnique('brands', 'brands_tenant_id_store_id_slug_unique', ['tenant_id', 'store_id', 'slug']);
        $this->ensureUnique('catalog_attributes', 'catalog_attributes_tenant_id_store_id_code_unique', ['tenant_id', 'store_id', 'code']);

        $this->backfillStoreScopedTaxonomies();
    }

    public function down(): void
    {
        if (Schema::hasColumn('categories', 'store_id')) {
            Schema::table('categories', function (Blueprint $table) {
                foreach (Schema::getIndexes('categories') as $index) {
                    if (($index['name'] ?? '') === 'categories_catalog_id_store_id_slug_unique') {
                        $table->dropUnique('categories_catalog_id_store_id_slug_unique');
                        break;
                    }
                }
                $table->dropIndex(['tenant_id', 'store_id', 'is_active']);
                $table->dropConstrainedForeignId('store_id');
            });
        }
    }

    private function ensureStoreColumn(string $table): void
    {
        if (! Schema::hasTable($table) || Schema::hasColumn($table, 'store_id')) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) {
            $blueprint->foreignUuid('store_id')
                ->nullable()
                ->after('tenant_id')
                ->constrained('stores')
                ->cascadeOnDelete();
            $blueprint->index(['tenant_id', 'store_id']);
        });
    }

    /**
     * @param  list<string>  $columns
     */
    private function dropUniqueIfColumns(string $table, array $columns): void
    {
        if (! Schema::hasTable($table)) {
            return;
        }

        foreach (Schema::getIndexes($table) as $index) {
            if (! ($index['unique'] ?? false) || ($index['primary'] ?? false)) {
                continue;
            }

            if (($index['columns'] ?? []) !== $columns) {
                continue;
            }

            $name = $index['name'] ?? null;
            if (! is_string($name) || $name === '') {
                continue;
            }

            try {
                Schema::table($table, function (Blueprint $blueprint) use ($name) {
                    $blueprint->dropUnique($name);
                });
            } catch (\Throwable) {
                // Index may already be gone (SQLite / partial prior runs).
            }
        }
    }

    /**
     * @param  list<string>  $columns
     */
    private function ensureUnique(string $table, string $name, array $columns): void
    {
        if (! Schema::hasTable($table)) {
            return;
        }

        foreach (Schema::getIndexes($table) as $index) {
            if (($index['name'] ?? '') === $name) {
                return;
            }
            if (($index['unique'] ?? false) && ($index['columns'] ?? []) === $columns) {
                return;
            }
        }

        try {
            Schema::table($table, function (Blueprint $blueprint) use ($name, $columns) {
                $blueprint->unique($columns, $name);
            });
        } catch (\Throwable) {
            // Unique may already exist under another driver-specific name.
        }
    }

    private function backfillStoreScopedTaxonomies(): void
    {
        $storesByCompany = Store::query()
            ->with('branch')
            ->orderBy('created_at')
            ->get()
            ->groupBy(fn (Store $store) => $store->branch?->company_id);

        foreach ($storesByCompany as $companyId => $stores) {
            if (! $companyId || $stores->isEmpty()) {
                continue;
            }

            /** @var Store $primary */
            $primary = $stores->first();
            $others = $stores->slice(1)->values();

            Brand::query()
                ->where('tenant_id', $primary->tenant_id)
                ->whereNull('store_id')
                ->update(['store_id' => $primary->id]);

            CatalogAttribute::query()
                ->where('tenant_id', $primary->tenant_id)
                ->whereNull('store_id')
                ->update(['store_id' => $primary->id]);

            $catalogIds = Catalog::query()
                ->where('company_id', $companyId)
                ->pluck('id');

            Category::query()
                ->whereIn('catalog_id', $catalogIds)
                ->whereNull('store_id')
                ->update(['store_id' => $primary->id]);

            foreach ($others as $store) {
                $this->cloneBrands($primary, $store);
                $this->cloneAttributes($primary, $store);
                $this->cloneCategories($primary, $store, $catalogIds->all());
            }
        }
    }

    private function cloneBrands(Store $from, Store $to): void
    {
        Brand::query()
            ->where('store_id', $from->id)
            ->orderBy('name')
            ->get()
            ->each(function (Brand $brand) use ($to): void {
                $exists = Brand::query()
                    ->where('tenant_id', $to->tenant_id)
                    ->where('store_id', $to->id)
                    ->where('slug', $brand->slug)
                    ->exists();

                if ($exists) {
                    return;
                }

                try {
                    Brand::query()->create([
                        'tenant_id' => $to->tenant_id,
                        'store_id' => $to->id,
                        'name' => $brand->name,
                        'slug' => $brand->slug,
                        'description' => $brand->description,
                        'logo_url' => $brand->logo_url,
                        'is_active' => $brand->is_active,
                    ]);
                } catch (UniqueConstraintViolationException) {
                    return;
                }
            });
    }

    private function cloneAttributes(Store $from, Store $to): void
    {
        CatalogAttribute::query()
            ->where('store_id', $from->id)
            ->orderBy('sort_order')
            ->get()
            ->each(function (CatalogAttribute $attribute) use ($to): void {
                $exists = CatalogAttribute::query()
                    ->where('tenant_id', $to->tenant_id)
                    ->where('store_id', $to->id)
                    ->where('code', $attribute->code)
                    ->exists();

                if ($exists) {
                    return;
                }

                try {
                    CatalogAttribute::query()->create([
                        'tenant_id' => $to->tenant_id,
                        'store_id' => $to->id,
                        'name' => $attribute->name,
                        'code' => $attribute->code,
                        'values' => $attribute->values,
                        'sort_order' => $attribute->sort_order,
                        'is_active' => $attribute->is_active,
                    ]);
                } catch (UniqueConstraintViolationException) {
                    return;
                }
            });
    }

    /**
     * @param  list<string>  $catalogIds
     */
    private function cloneCategories(Store $from, Store $to, array $catalogIds): void
    {
        if ($catalogIds === []) {
            return;
        }

        $roots = Category::query()
            ->whereIn('catalog_id', $catalogIds)
            ->where('store_id', $from->id)
            ->whereNull('parent_id')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        foreach ($roots as $root) {
            $this->cloneCategoryNode($root, $to, null);
        }
    }

    private function cloneCategoryNode(Category $source, Store $to, ?string $parentId): void
    {
        $exists = Category::query()
            ->where('catalog_id', $source->catalog_id)
            ->where('store_id', $to->id)
            ->where('slug', $source->slug)
            ->where('parent_id', $parentId)
            ->exists();

        if ($exists) {
            $clone = Category::query()
                ->where('catalog_id', $source->catalog_id)
                ->where('store_id', $to->id)
                ->where('slug', $source->slug)
                ->where('parent_id', $parentId)
                ->first();
        } else {
            try {
                $clone = Category::query()->create([
                    'tenant_id' => $to->tenant_id,
                    'catalog_id' => $source->catalog_id,
                    'store_id' => $to->id,
                    'parent_id' => $parentId,
                    'name' => $source->name,
                    'slug' => $source->slug ?: Str::slug($source->name),
                    'sort_order' => $source->sort_order,
                    'is_active' => $source->is_active,
                ]);
            } catch (UniqueConstraintViolationException) {
                $clone = Category::query()
                    ->where('catalog_id', $source->catalog_id)
                    ->where('store_id', $to->id)
                    ->where('slug', $source->slug)
                    ->first();
            }
        }

        if (! $clone) {
            return;
        }

        $children = Category::query()
            ->where('parent_id', $source->id)
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        foreach ($children as $child) {
            $this->cloneCategoryNode($child, $to, $clone->id);
        }
    }
};
