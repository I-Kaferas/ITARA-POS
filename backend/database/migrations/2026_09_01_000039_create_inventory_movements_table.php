<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_movements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('warehouse_id')->constrained('warehouses')->restrictOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->restrictOnDelete();
            $table->foreignUuid('product_variant_id')->nullable()->constrained('product_variants')->nullOnDelete();
            $table->foreignUuid('batch_id')->nullable()->constrained('batches')->nullOnDelete();
            $table->foreignUuid('serial_number_id')->nullable()->constrained('serial_numbers')->nullOnDelete();
            $table->string('movement_type', 30);
            $table->bigInteger('quantity');
            $table->bigInteger('unit_cost')->nullable();
            $table->string('reference_type', 100)->nullable();
            $table->uuid('reference_id')->nullable();
            $table->foreignUuid('source_warehouse_id')->nullable()->constrained('warehouses')->nullOnDelete();
            $table->foreignUuid('destination_warehouse_id')->nullable()->constrained('warehouses')->nullOnDelete();
            $table->foreignUuid('performed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('notes')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamp('created_at')->useCurrent();

            $table->index(['tenant_id', 'warehouse_id', 'product_id']);
            $table->index(['tenant_id', 'movement_type']);
            $table->index(['tenant_id', 'occurred_at']);
            $table->index(['reference_type', 'reference_id']);
            $table->index(['tenant_id', 'batch_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_movements');
    }
};
