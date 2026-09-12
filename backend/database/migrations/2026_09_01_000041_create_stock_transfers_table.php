<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_transfers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('transfer_number', 50);
            $table->foreignUuid('source_warehouse_id')->constrained('warehouses')->restrictOnDelete();
            $table->foreignUuid('destination_warehouse_id')->constrained('warehouses')->restrictOnDelete();
            $table->string('status', 30)->default('draft');
            $table->foreignUuid('requested_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUuid('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('notes')->nullable();
            $table->timestamp('shipped_at')->nullable();
            $table->timestamp('received_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'transfer_number']);
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'source_warehouse_id']);
            $table->index(['tenant_id', 'destination_warehouse_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_transfers');
    }
};
