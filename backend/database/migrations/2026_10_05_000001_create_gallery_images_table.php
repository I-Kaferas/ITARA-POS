<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('gallery_images', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('catalog_id')->nullable()->constrained('catalogs')->nullOnDelete();
            $table->string('storage_path', 500);
            $table->string('cdn_url', 1000);
            $table->string('original_filename')->nullable();
            $table->string('mime_type', 100);
            $table->unsignedInteger('file_size')->default(0);
            $table->timestamps();
            $table->softDeletes();

            $table->index(['tenant_id', 'catalog_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('gallery_images');
    }
};
