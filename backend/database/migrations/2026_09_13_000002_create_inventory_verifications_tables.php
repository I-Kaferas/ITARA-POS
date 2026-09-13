<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_verification_plans', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('name', 160);
            $table->foreignUuid('warehouse_id')->constrained('warehouses')->cascadeOnDelete();
            $table->foreignUuid('category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('inventory_class', 1)->nullable();
            $table->string('frequency', 20)->default('weekly');
            $table->foreignUuid('responsible_id')->nullable()->constrained('users')->nullOnDelete();
            $table->date('next_run_at')->nullable();
            $table->text('notes')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['warehouse_id', 'is_active', 'next_run_at']);
        });

        Schema::create('inventory_verification_runs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('plan_id')->nullable()->constrained('inventory_verification_plans')->nullOnDelete();
            $table->string('reference', 40);
            $table->foreignUuid('warehouse_id')->constrained('warehouses')->cascadeOnDelete();
            $table->string('status', 20)->default('analysis');
            $table->foreignUuid('performed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('analyzed_at')->nullable();
            $table->json('summary')->nullable();
            $table->foreignUuid('validated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('validated_at')->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'reference']);
            $table->index(['warehouse_id', 'created_at']);
        });

        Schema::create('inventory_verification_findings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('run_id')->constrained('inventory_verification_runs')->cascadeOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->cascadeOnDelete();
            $table->string('check_type', 40);
            $table->string('code', 60);
            $table->string('severity', 20)->default('warning');
            $table->string('status', 20)->default('open');
            $table->string('title');
            $table->text('message')->nullable();
            $table->string('expected_value')->nullable();
            $table->string('actual_value')->nullable();
            $table->text('note')->nullable();
            $table->string('action_taken', 80)->nullable();
            $table->foreignUuid('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['run_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_verification_findings');
        Schema::dropIfExists('inventory_verification_runs');
        Schema::dropIfExists('inventory_verification_plans');
    }
};
