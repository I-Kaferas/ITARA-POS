<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('products') && ! Schema::hasColumn('products', 'accompaniment_enabled')) {
            Schema::table('products', function (Blueprint $table) {
                $table->boolean('accompaniment_enabled')->default(false)->after('metadata');
            });
        }

        if (Schema::hasTable('sale_items') && ! Schema::hasColumn('sale_items', 'is_accompaniment')) {
            Schema::table('sale_items', function (Blueprint $table) {
                $table->boolean('is_accompaniment')->default(false);
            });
        }

        if (! Schema::hasTable('product_accompaniment_links')) {
            Schema::create('product_accompaniment_links', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('product_id')->constrained('products')->cascadeOnDelete();
                $table->foreignUuid('accompaniment_product_id')->constrained('products')->cascadeOnDelete();
                $table->unsignedInteger('sort_order')->default(0);
                $table->timestamps();

                $table->unique(['product_id', 'accompaniment_product_id'], 'product_accompaniment_unique');
                $table->index(['tenant_id', 'product_id']);
                $table->index(['tenant_id', 'accompaniment_product_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('product_accompaniment_links');

        if (Schema::hasTable('sale_items') && Schema::hasColumn('sale_items', 'is_accompaniment')) {
            Schema::table('sale_items', function (Blueprint $table) {
                $table->dropColumn('is_accompaniment');
            });
        }

        if (Schema::hasTable('products') && Schema::hasColumn('products', 'accompaniment_enabled')) {
            Schema::table('products', function (Blueprint $table) {
                $table->dropColumn('accompaniment_enabled');
            });
        }
    }
};
