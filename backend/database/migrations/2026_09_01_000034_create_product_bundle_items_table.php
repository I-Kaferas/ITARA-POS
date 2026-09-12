<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_bundle_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('bundle_product_id')->constrained('products')->cascadeOnDelete();
            $table->foreignUuid('component_product_id')->constrained('products')->cascadeOnDelete();
            $table->foreignUuid('component_variant_id')->nullable()->constrained('product_variants')->nullOnDelete();
            $table->decimal('quantity', 12, 4)->default(1);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->unique(['bundle_product_id', 'component_product_id', 'component_variant_id'], 'bundle_component_unique');
            $table->index(['tenant_id', 'bundle_product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_bundle_items');
    }
};
