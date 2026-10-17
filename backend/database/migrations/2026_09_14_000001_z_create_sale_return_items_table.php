<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sale_return_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('sale_return_id')->constrained('sale_returns')->cascadeOnDelete();
            $table->foreignUuid('sale_item_id')->constrained('sale_items')->restrictOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('products')->restrictOnDelete();
            $table->foreignUuid('product_variant_id')->nullable()->constrained('product_variants')->nullOnDelete();
            $table->string('product_name');
            $table->string('product_sku', 120)->nullable();
            $table->integer('quantity_returned');
            $table->bigInteger('unit_price');
            $table->decimal('tax_rate', 8, 4)->default(0);
            $table->bigInteger('line_subtotal')->default(0);
            $table->bigInteger('line_tax')->default(0);
            $table->bigInteger('line_total')->default(0);
            $table->foreignUuid('batch_id')->nullable()->constrained('batches')->nullOnDelete();
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();

            $table->index(['tenant_id', 'sale_return_id']);
            $table->index(['tenant_id', 'sale_item_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_return_items');
    }
};
