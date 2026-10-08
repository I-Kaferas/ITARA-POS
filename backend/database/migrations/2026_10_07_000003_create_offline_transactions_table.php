<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('offline_transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->uuid('client_uuid');
            $table->string('domain', 32);
            $table->string('entity_type', 40);
            $table->string('entity_id', 80);
            $table->string('operation', 40);
            $table->string('payload_hash', 64);
            $table->json('payload');
            $table->string('base_version', 64)->nullable();
            $table->string('status', 20);
            $table->json('result')->nullable();
            $table->string('conflict_code', 40)->nullable();
            $table->text('error')->nullable();
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->timestamp('synced_at')->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'client_uuid']);
            $table->index(['store_id', 'status']);
        });

        Schema::table('cashier_shifts', function (Blueprint $table) {
            if (! Schema::hasColumn('cashier_shifts', 'client_uuid')) {
                $table->uuid('client_uuid')->nullable();
                $table->unique(['tenant_id', 'client_uuid']);
            }
        });
    }

    public function down(): void
    {
        Schema::table('cashier_shifts', function (Blueprint $table) {
            if (Schema::hasColumn('cashier_shifts', 'client_uuid')) {
                $table->dropUnique(['tenant_id', 'client_uuid']);
                $table->dropColumn('client_uuid');
            }
        });

        Schema::dropIfExists('offline_transactions');
    }
};
