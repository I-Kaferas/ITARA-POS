<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('company_payment_methods', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->string('code', 30);
            $table->string('label', 100);
            $table->string('label_fr', 100)->nullable();
            $table->boolean('is_enabled')->default(true);
            $table->boolean('available_on_pos')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->json('config')->nullable();
            $table->timestamps();

            $table->unique(['company_id', 'code']);
            $table->index(['tenant_id', 'company_id', 'is_enabled']);
            $table->index(['company_id', 'available_on_pos', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('company_payment_methods');
    }
};
