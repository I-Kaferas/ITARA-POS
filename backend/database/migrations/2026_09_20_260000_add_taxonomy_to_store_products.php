<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('store_products', function (Blueprint $table) {
            $table->foreignUuid('category_id')
                ->nullable()
                ->after('product_id')
                ->constrained('categories')
                ->nullOnDelete();
            $table->foreignUuid('brand_id')
                ->nullable()
                ->after('category_id')
                ->constrained('brands')
                ->nullOnDelete();
            $table->foreignUuid('unit_id')
                ->nullable()
                ->after('brand_id')
                ->constrained('units')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('store_products', function (Blueprint $table) {
            $table->dropConstrainedForeignId('category_id');
            $table->dropConstrainedForeignId('brand_id');
            $table->dropConstrainedForeignId('unit_id');
        });
    }
};
