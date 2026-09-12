<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_alerts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('warehouse_id')->nullable()->constrained('warehouses')->cascadeOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->cascadeOnDelete();
            $table->foreignUuid('batch_id')->nullable()->constrained('batches')->nullOnDelete();
            $table->string('alert_type', 30);
            $table->string('status', 20)->default('active');
            $table->bigInteger('quantity_on_hand')->nullable();
            $table->bigInteger('threshold_value')->nullable();
            $table->date('expires_at')->nullable();
            $table->text('message')->nullable();
            $table->timestamp('acknowledged_at')->nullable();
            $table->foreignUuid('acknowledged_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'status', 'alert_type']);
            $table->index(['tenant_id', 'warehouse_id', 'product_id']);
            $table->index(['tenant_id', 'batch_id']);
            $table->index(['tenant_id', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_alerts');
    }
};
