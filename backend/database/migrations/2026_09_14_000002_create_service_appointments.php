<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('service_offerings')) {
            Schema::create('service_offerings', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->string('name');
                $table->string('category', 40);
                $table->unsignedInteger('duration_minutes')->default(60);
                $table->unsignedBigInteger('price')->default(0);
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('service_appointments')) {
            Schema::create('service_appointments', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('store_id')->nullable()->constrained('stores')->nullOnDelete();
                $table->foreignUuid('service_offering_id')->constrained('service_offerings')->restrictOnDelete();
                $table->string('customer_name');
                $table->foreignUuid('employee_id')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('scheduled_at');
                $table->string('status', 20)->default('booked');
                $table->timestamp('completed_at')->nullable();
                $table->foreignUuid('completed_by')->nullable()->constrained('users')->nullOnDelete();
                $table->text('completion_notes')->nullable();
                $table->timestamp('paid_at')->nullable();
                $table->string('payment_method', 40)->nullable();
                $table->unsignedBigInteger('paid_amount')->nullable();
                $table->uuid('sale_id')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('service_appointments');
        Schema::dropIfExists('service_offerings');
    }
};
