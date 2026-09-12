<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_images', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->cascadeOnDelete();
            $table->string('storage_path', 500);
            $table->string('cdn_url', 1000);
            $table->string('original_filename')->nullable();
            $table->string('mime_type', 100);
            $table->unsignedInteger('file_size')->default(0);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->boolean('is_primary')->default(false);
            $table->string('alt_text')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['tenant_id', 'product_id']);
            $table->index(['product_id', 'sort_order']);
            $table->index(['product_id', 'is_primary']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_images');
    }
};
