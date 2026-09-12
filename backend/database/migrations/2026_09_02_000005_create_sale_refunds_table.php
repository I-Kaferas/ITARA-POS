<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sale_refunds', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('sale_return_id')->constrained('sale_returns')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->constrained('sales')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->string('refund_number', 50);
            $table->string('refund_method', 30);
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('USD');
            $table->string('status', 20)->default('completed');
            $table->foreignUuid('payment_transaction_id')->nullable()->constrained('payment_transactions')->nullOnDelete();
            $table->foreignUuid('customer_transaction_id')->nullable()->constrained('customer_transactions')->nullOnDelete();
            $table->foreignUuid('cash_register_id')->nullable()->constrained('cash_registers')->nullOnDelete();
            $table->foreignUuid('original_payment_transaction_id')->nullable()->constrained('payment_transactions')->nullOnDelete();
            $table->foreignUuid('processed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->jsonb('metadata')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'refund_number']);
            $table->index(['tenant_id', 'sale_return_id']);
            $table->index(['tenant_id', 'sale_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_refunds');
    }
};
