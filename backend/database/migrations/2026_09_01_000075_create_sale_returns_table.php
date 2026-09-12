<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sale_returns', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->constrained('sales')->restrictOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->restrictOnDelete();
            $table->foreignUuid('warehouse_id')->constrained('warehouses')->restrictOnDelete();
            $table->foreignUuid('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->string('return_number', 50);
            $table->string('status', 30)->default('completed');
            $table->string('reason', 100);
            $table->string('refund_method', 30)->default('none');
            $table->bigInteger('subtotal')->default(0);
            $table->bigInteger('tax_total')->default(0);
            $table->bigInteger('discount_total')->default(0);
            $table->bigInteger('total')->default(0);
            $table->string('currency', 3)->default('USD');
            $table->foreignUuid('processed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUuid('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('idempotency_key', 100)->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'return_number']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->index(['tenant_id', 'sale_id']);
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'completed_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_returns');
    }
};
