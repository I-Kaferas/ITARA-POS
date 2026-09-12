<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sale_receipts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->constrained('sales')->cascadeOnDelete();
            $table->string('receipt_number', 50);
            $table->string('format', 20)->default('thermal_80');
            $table->foreignUuid('printed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained('devices')->nullOnDelete();
            $table->timestamp('printed_at');
            $table->unsignedInteger('reprint_count')->default(0);
            $table->timestamps();

            $table->unique(['tenant_id', 'receipt_number']);
            $table->index(['tenant_id', 'sale_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_receipts');
    }
};
