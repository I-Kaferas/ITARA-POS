<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('promotions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->foreignUuid('category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('name');
            $table->string('code', 50)->nullable();
            $table->string('type', 40);
            $table->text('description')->nullable();
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->unsignedInteger('min_quantity')->default(1);
            $table->unsignedInteger('max_uses')->nullable();
            $table->unsignedInteger('uses_count')->default(0);
            $table->integer('priority')->default(0);
            $table->decimal('discount_percent', 5, 2)->nullable();
            $table->bigInteger('discount_amount')->nullable();
            $table->unsignedInteger('buy_quantity')->nullable();
            $table->unsignedInteger('get_quantity')->nullable();
            $table->bigInteger('bundle_price')->nullable();
            $table->json('schedule')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'is_active', 'priority']);
            $table->index(['tenant_id', 'store_id']);
        });

        Schema::create('promotion_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('promotion_id')->constrained('promotions')->cascadeOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('products')->cascadeOnDelete();
            $table->foreignUuid('product_variant_id')->nullable()->constrained('product_variants')->cascadeOnDelete();
            $table->string('role', 20);
            $table->unsignedInteger('quantity')->default(1);
            $table->timestamps();

            $table->index(['promotion_id', 'role']);
        });

        Schema::create('promotion_customers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('promotion_id')->constrained('promotions')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->constrained('customers')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['promotion_id', 'customer_id']);
        });

        if (! Schema::hasTable('sale_discounts')) {
            Schema::create('sale_discounts', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('sale_id')->constrained('sales')->cascadeOnDelete();
                $table->uuid('sale_item_id')->nullable();
                $table->foreignUuid('promotion_id')->nullable()->constrained('promotions')->nullOnDelete();
                $table->string('discount_type', 30);
                $table->string('source', 30);
                $table->string('label')->nullable();
                $table->bigInteger('amount');
                $table->unsignedInteger('sort_order')->default(0);
                $table->timestamps();

                $table->index(['sale_id', 'sort_order']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_discounts');
        Schema::dropIfExists('promotion_customers');
        Schema::dropIfExists('promotion_items');
        Schema::dropIfExists('promotions');
    }
};
