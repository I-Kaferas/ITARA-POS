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

        Schema::table('catalogs', function (Blueprint $table) {
            foreach (Schema::getIndexes('catalogs') as $index) {
                if (($index['name'] ?? '') === 'catalogs_store_id_unique') {
                    $table->dropUnique(['store_id']);
                    break;
                }
            }
        });
    }

    public function down(): void
    {
        Schema::table('catalogs', function (Blueprint $table) {
            $table->unique('store_id');
        });
    }
};
