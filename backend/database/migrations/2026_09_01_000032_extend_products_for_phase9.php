<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->string('product_type', 30)->default('simple')->after('category_id');
            $table->foreignUuid('brand_id')->nullable()->after('product_type')->constrained('brands')->nullOnDelete();
            $table->foreignUuid('unit_id')->nullable()->after('brand_id')->constrained('units')->nullOnDelete();
            $table->foreignUuid('tax_id')->nullable()->after('unit_id')->constrained('taxes')->nullOnDelete();
            $table->boolean('is_serialized')->default(false)->after('is_active');
            $table->boolean('track_batch')->default(false)->after('is_serialized');
            $table->boolean('track_expiration')->default(false)->after('track_batch');
            $table->unsignedSmallInteger('expiration_days')->nullable()->after('track_expiration');

            $table->index(['tenant_id', 'product_type']);
            $table->index(['tenant_id', 'brand_id']);
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropForeign(['brand_id']);
            $table->dropForeign(['unit_id']);
            $table->dropForeign(['tax_id']);
            $table->dropColumn([
                'product_type',
                'brand_id',
                'unit_id',
                'tax_id',
                'is_serialized',
                'track_batch',
                'track_expiration',
                'expiration_days',
            ]);
        });
    }
};
