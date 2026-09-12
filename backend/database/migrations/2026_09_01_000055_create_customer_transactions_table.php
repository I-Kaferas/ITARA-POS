<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->constrained('customers')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->nullable()->constrained('sales')->nullOnDelete();
            $table->foreignUuid('customer_payment_id')->nullable()->constrained('customer_payments')->nullOnDelete();
            $table->string('transaction_type', 30);
            $table->string('reference', 100)->nullable();
            $table->bigInteger('amount');
            $table->bigInteger('paid_amount')->default(0);
            $table->date('due_date')->nullable();
            $table->unsignedInteger('loyalty_points_delta')->default(0);
            $table->text('description')->nullable();
            $table->foreignUuid('recorded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('occurred_at');
            $table->timestamp('created_at')->useCurrent();

            $table->index(['tenant_id', 'customer_id', 'occurred_at']);
            $table->index(['tenant_id', 'transaction_type']);
            $table->index(['tenant_id', 'due_date']);
            $table->index(['tenant_id', 'sale_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_transactions');
    }
};
