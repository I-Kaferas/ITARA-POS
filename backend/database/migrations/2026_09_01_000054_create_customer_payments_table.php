<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->constrained('customers')->cascadeOnDelete();
            $table->string('payment_number', 50);
            $table->bigInteger('amount');
            $table->string('payment_method', 30)->default('cash');
            $table->string('reference', 100)->nullable();
            $table->text('notes')->nullable();
            $table->string('status', 20)->default('completed');
            $table->timestamp('paid_at');
            $table->foreignUuid('recorded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->jsonb('allocations')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'payment_number']);
            $table->index(['tenant_id', 'customer_id']);
            $table->index(['tenant_id', 'paid_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_payments');
    }
};
