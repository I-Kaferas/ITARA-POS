<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pos_reservations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->string('reference', 40);
            $table->string('guest_name', 160);
            $table->string('phone', 40)->nullable();
            $table->unsignedSmallInteger('party_size');
            $table->dateTime('reserved_at');
            $table->string('table_label', 40)->nullable();
            $table->string('status', 20)->default('pending');
            $table->text('notes')->nullable();
            $table->foreignUuid('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['tenant_id', 'reference']);
            $table->index(['store_id', 'reserved_at']);
            $table->index(['store_id', 'status', 'reserved_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pos_reservations');
    }
};
