<?php

use App\Models\Catalog;
use App\Models\Store;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('catalogs', 'store_id')) {
            Catalog::query()
                ->whereNotNull('store_id')
                ->with('products')
                ->orderBy('created_at')
                ->get()
                ->each(function (Catalog $catalog): void {
                    $store = Store::query()->find($catalog->store_id);
                    if (! $store) {
                        return;
                    }

                    foreach ($catalog->products as $product) {
                        $product->importToStore($store);
                    }
                });

            Catalog::query()->whereNotNull('store_id')->update(['store_id' => null]);
        }

        if (! Schema::hasColumn('catalogs', 'store_id')) {
            return;
        }

        $hasStoreUnique = collect(Schema::getIndexes('catalogs'))
            ->contains(fn (array $index): bool => ($index['name'] ?? '') === 'catalogs_store_id_unique');

        if (! $hasStoreUnique) {
            return;
        }

        // MySQL cannot drop a unique index still used by a foreign key.
        Schema::table('catalogs', function (Blueprint $table) {
            $table->dropForeign(['store_id']);
        });

        Schema::table('catalogs', function (Blueprint $table) {
            $table->dropUnique(['store_id']);
        });

        Schema::table('catalogs', function (Blueprint $table) {
            $table->foreign('store_id')
                ->references('id')
                ->on('stores')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        if (! Schema::hasColumn('catalogs', 'store_id')) {
            return;
        }

        Schema::table('catalogs', function (Blueprint $table) {
            $table->dropForeign(['store_id']);
        });

        Schema::table('catalogs', function (Blueprint $table) {
            $table->unique('store_id');
            $table->foreign('store_id')
                ->references('id')
                ->on('stores')
                ->nullOnDelete();
        });
    }
};
