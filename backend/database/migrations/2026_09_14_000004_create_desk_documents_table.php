<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('desk_documents')) {
            return;
        }

        Schema::create('desk_documents', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->string('code', 80);
            $table->string('kind', 40);
            $table->string('parent_code', 80)->nullable();
            $table->string('status', 40)->nullable();
            $table->json('payload');
            $table->timestamps();

            $table->unique(['store_id', 'code']);
            $table->index(['store_id', 'kind']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('desk_documents');
    }
};
