<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('barcodes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->uuidMorphs('barcodeable');
            $table->string('barcode', 100);
            $table->string('type', 20)->default('internal');
            $table->boolean('is_primary')->default(false);
            $table->timestamps();

            $table->unique(['tenant_id', 'barcode']);
            $table->index(['tenant_id', 'barcodeable_type', 'barcodeable_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('barcodes');
    }
};
