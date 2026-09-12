<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('catalog_id')->constrained('catalogs')->cascadeOnDelete();
            $table->foreignUuid('category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('sku', 100);
            $table->string('name');
            $table->text('description')->nullable();
            $table->string('barcode', 100)->nullable();
            $table->string('unit', 50)->default('piece');
            $table->bigInteger('base_price')->default(0);
            $table->bigInteger('cost_price')->default(0);
            $table->boolean('is_active')->default(true);
            $table->jsonb('metadata')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'sku']);
            $table->index(['tenant_id', 'catalog_id']);
            $table->index(['tenant_id', 'category_id']);
            $table->index(['tenant_id', 'barcode']);
            $table->index(['tenant_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
