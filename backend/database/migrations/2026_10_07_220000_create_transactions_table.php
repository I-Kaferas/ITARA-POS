<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('transactions')) {
            return;
        }

        Schema::create('transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('reference', 40);
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('party_id')->nullable()->constrained('parties')->nullOnDelete();
            $table->foreignUuid('branch_id')->nullable()->constrained('branches')->nullOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type', 30);
            $table->date('date');
            $table->string('status', 20)->default('pending');
            $table->bigInteger('amount')->default(0);
            $table->char('currency', 3)->default('FBU');
            $table->string('payment_status', 30)->default('unpaid');
            $table->nullableUuidMorphs('source');
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'reference']);
            $table->index(['tenant_id', 'type']);
            $table->index(['tenant_id', 'party_id']);
            $table->index(['tenant_id', 'branch_id']);
            $table->index(['tenant_id', 'date']);
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'payment_status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
