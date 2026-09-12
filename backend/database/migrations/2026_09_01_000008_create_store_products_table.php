<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('store_products', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->cascadeOnDelete();
            $table->boolean('is_available')->default(true);
            $table->bigInteger('price_override')->nullable();
            $table->timestamp('imported_at')->useCurrent();
            $table->timestamps();

            $table->unique(['store_id', 'product_id']);
            $table->index(['tenant_id', 'store_id']);
            $table->index(['tenant_id', 'product_id']);
            $table->index(['tenant_id', 'store_id', 'is_available']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('store_products');
    }
};
