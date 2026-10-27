<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('recurring_expenses')) {
            return;
        }

        Schema::create('recurring_expenses', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('branch_id')->nullable()->constrained('branches')->nullOnDelete();
            $table->foreignUuid('store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->foreignUuid('expense_category_id')->nullable()->constrained('expense_categories')->nullOnDelete();
            $table->foreignUuid('cash_register_id')->nullable()->constrained('cash_registers')->nullOnDelete();
            $table->string('name');
            $table->unsignedBigInteger('amount');
            $table->string('currency_code', 3)->default('BIF');
            $table->string('frequency', 20)->default('monthly');
            $table->date('next_due_on');
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['tenant_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('recurring_expenses');
    }
};
