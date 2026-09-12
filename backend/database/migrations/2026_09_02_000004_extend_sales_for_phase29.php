<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sales', function (Blueprint $table) {
            $table->bigInteger('paid_amount')->default(0)->after('total');
            $table->date('due_date')->nullable()->after('paid_amount');
            $table->string('payment_status', 20)->default('paid')->after('due_date');

            $table->index(['tenant_id', 'payment_status']);
            $table->index(['tenant_id', 'due_date']);
        });

        Schema::create('sale_installments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('sale_id');
            $table->unsignedSmallInteger('installment_number');
            $table->bigInteger('amount');
            $table->bigInteger('paid_amount')->default(0);
            $table->date('due_date');
            $table->string('status', 20)->default('pending');
            $table->timestamps();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('sale_id')->references('id')->on('sales')->cascadeOnDelete();
            $table->unique(['sale_id', 'installment_number']);
            $table->index(['tenant_id', 'due_date']);
            $table->index(['tenant_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_installments');

        Schema::table('sales', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'payment_status']);
            $table->dropIndex(['tenant_id', 'due_date']);
            $table->dropColumn(['paid_amount', 'due_date', 'payment_status']);
        });
    }
};
