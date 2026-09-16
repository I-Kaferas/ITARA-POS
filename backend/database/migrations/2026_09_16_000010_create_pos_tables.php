<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pos_table_zones', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->string('name', 80);
            $table->text('description')->nullable();
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['store_id', 'name']);
            $table->index(['store_id', 'sort_order']);
        });

        Schema::create('pos_tables', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('zone_id')->nullable()->constrained('pos_table_zones')->nullOnDelete();
            $table->string('name', 80);
            $table->string('code', 40);
            $table->unsignedSmallInteger('capacity')->default(2);
            $table->text('description')->nullable();
            $table->string('status', 20)->default('available');
            $table->boolean('is_active')->default(true);
            $table->uuid('current_sale_id')->nullable();
            $table->timestamps();

            $table->unique(['store_id', 'code']);
            $table->index(['store_id', 'status']);
            $table->index(['store_id', 'zone_id']);
            $table->index('current_sale_id');
        });

        Schema::create('pos_table_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('table_id')->constrained('pos_tables')->cascadeOnDelete();
            $table->foreignUuid('sale_id')->nullable()->constrained('sales')->nullOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type', 40);
            $table->uuid('from_table_id')->nullable();
            $table->uuid('to_table_id')->nullable();
            $table->json('payload')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['table_id', 'created_at']);
            $table->index(['sale_id', 'created_at']);
            $table->index(['store_id', 'type']);
        });

        Schema::table('sales', function (Blueprint $table) {
            $table->foreignUuid('table_id')->nullable()->after('store_id')->constrained('pos_tables')->nullOnDelete();
            $table->foreignUuid('merged_into_id')->nullable()->after('table_id')->constrained('sales')->nullOnDelete();
            $table->index(['table_id', 'status']);
        });

        Schema::table('pos_reservations', function (Blueprint $table) {
            $table->foreignUuid('table_id')->nullable()->after('table_label')->constrained('pos_tables')->nullOnDelete();
            $table->index(['table_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::table('pos_reservations', function (Blueprint $table) {
            $table->dropConstrainedForeignId('table_id');
        });

        Schema::table('sales', function (Blueprint $table) {
            $table->dropConstrainedForeignId('merged_into_id');
            $table->dropConstrainedForeignId('table_id');
        });

        Schema::dropIfExists('pos_table_events');
        Schema::dropIfExists('pos_tables');
        Schema::dropIfExists('pos_table_zones');
    }
};
