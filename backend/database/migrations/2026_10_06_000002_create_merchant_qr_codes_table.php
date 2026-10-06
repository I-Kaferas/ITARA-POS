<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('merchant_qr_codes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignUuid('store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->foreignUuid('table_id')->nullable()->constrained('pos_tables')->nullOnDelete();
            $table->string('label');
            $table->string('type', 32);
            $table->string('scan', 16);
            $table->string('service', 16);
            $table->json('payload');
            $table->text('scan_value');
            $table->timestamps();

            $table->index(['tenant_id', 'company_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('merchant_qr_codes');
    }
};
