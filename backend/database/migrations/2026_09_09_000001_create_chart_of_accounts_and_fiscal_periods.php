<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('accounting_entries')) {
            Schema::create('accounting_entries', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->string('entry_type', 60);
                $table->string('reference_type')->nullable();
                $table->uuid('reference_id')->nullable();
                $table->bigInteger('debit')->default(0);
                $table->bigInteger('credit')->default(0);
                $table->string('account_code', 20);
                $table->text('description')->nullable();
                $table->foreignUuid('recorded_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('occurred_at')->nullable();
                $table->timestamp('created_at')->nullable();

                $table->index(['tenant_id', 'account_code']);
                $table->index(['tenant_id', 'reference_type', 'reference_id']);
                $table->index(['tenant_id', 'occurred_at']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('accounting_entries');
    }
};
