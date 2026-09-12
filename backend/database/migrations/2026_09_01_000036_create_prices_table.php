<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('prices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->uuidMorphs('priceable');
            $table->string('price_type', 30)->default('base');
            $table->bigInteger('amount');
            $table->string('currency_code', 3)->default('USD');
            $table->foreignUuid('store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->unsignedInteger('min_quantity')->default(1);
            $table->timestamp('valid_from')->nullable();
            $table->timestamp('valid_until')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['tenant_id', 'priceable_type', 'priceable_id']);
            $table->index(['tenant_id', 'store_id', 'price_type']);
            $table->index(['tenant_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('prices');
    }
};
