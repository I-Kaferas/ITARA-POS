<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('branches') && ! Schema::hasColumn('branches', 'settings')) {
            Schema::table('branches', function (Blueprint $table) {
                $table->json('settings')->nullable();
            });
        }

        if (Schema::hasTable('stores') && ! Schema::hasColumn('stores', 'kind')) {
            Schema::table('stores', function (Blueprint $table) {
                $table->string('kind', 20)->default('store');
            });
        }

        if (! Schema::hasTable('cash_registers') && Schema::hasTable('stores')) {
            Schema::create('cash_registers', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
                $table->foreignUuid('device_id')->nullable()->constrained('devices')->nullOnDelete();
                $table->string('name');
                $table->string('code', 50);
                $table->boolean('is_active')->default(true);
                $table->timestamps();
                $table->softDeletes();

                $table->unique(['tenant_id', 'code']);
                $table->index(['tenant_id', 'store_id']);
            });
        }

        if (! Schema::hasTable('cash_register_sessions') && Schema::hasTable('cash_registers')) {
            Schema::create('cash_register_sessions', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('cash_register_id')->constrained('cash_registers')->cascadeOnDelete();
                $table->foreignUuid('opened_by')->nullable()->constrained('users')->nullOnDelete();
                $table->foreignUuid('closed_by')->nullable()->constrained('users')->nullOnDelete();
                $table->string('status', 20)->default('open');
                $table->bigInteger('opening_balance')->default(0);
                $table->bigInteger('sales_total')->default(0);
                $table->bigInteger('cash_in_total')->default(0);
                $table->bigInteger('cash_out_total')->default(0);
                $table->bigInteger('expenses_total')->default(0);
                $table->bigInteger('expected_cash')->default(0);
                $table->bigInteger('actual_cash')->nullable();
                $table->bigInteger('variance')->nullable();
                $table->text('opening_notes')->nullable();
                $table->text('closing_notes')->nullable();
                $table->timestamp('opened_at')->nullable();
                $table->timestamp('closed_at')->nullable();
                $table->timestamps();

                $table->index(['tenant_id', 'cash_register_id', 'status']);
            });
        }

        if (! Schema::hasTable('cash_movements') && Schema::hasTable('cash_registers')) {
            Schema::create('cash_movements', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('cash_register_id')->constrained('cash_registers')->cascadeOnDelete();
                $table->foreignUuid('cash_register_session_id')->nullable()->constrained('cash_register_sessions')->nullOnDelete();
                $table->uuid('cashier_shift_id')->nullable();
                $table->string('movement_type', 40);
                $table->bigInteger('amount');
                $table->string('reference_type')->nullable();
                $table->uuid('reference_id')->nullable();
                $table->string('reference')->nullable();
                $table->string('description')->nullable();
                $table->foreignUuid('performed_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('occurred_at')->nullable();
                $table->timestamps();

                $table->index(['tenant_id', 'cash_register_id', 'occurred_at']);
            });
        }

        if (! Schema::hasTable('cashier_shifts') && Schema::hasTable('cash_registers')) {
            Schema::create('cashier_shifts', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('cashier_id')->nullable()->constrained('users')->nullOnDelete();
                $table->foreignUuid('cash_register_id')->constrained('cash_registers')->cascadeOnDelete();
                $table->foreignUuid('cash_register_session_id')->nullable()->constrained('cash_register_sessions')->nullOnDelete();
                $table->string('status', 20)->default('open');
                $table->bigInteger('opening_balance')->default(0);
                $table->bigInteger('expected_cash')->default(0);
                $table->text('opening_notes')->nullable();
                $table->timestamp('opened_at')->nullable();
                $table->timestamps();

                $table->index(['tenant_id', 'cash_register_id', 'status']);
            });
        }

        if (! Schema::hasTable('branch_expenses') && Schema::hasTable('branches')) {
            Schema::create('branch_expenses', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('branch_id')->constrained('branches')->cascadeOnDelete();
                $table->foreignUuid('store_id')->nullable()->constrained('stores')->nullOnDelete();
                $table->string('category', 80)->default('other');
                $table->string('description');
                $table->bigInteger('amount');
                $table->char('currency_code', 3)->default('FBU');
                $table->date('occurred_on');
                $table->text('notes')->nullable();
                $table->timestamps();

                $table->index(['tenant_id', 'branch_id', 'occurred_on']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_expenses');
        Schema::dropIfExists('cash_register_sessions');
        Schema::dropIfExists('cash_registers');

        if (Schema::hasTable('stores') && Schema::hasColumn('stores', 'kind')) {
            Schema::table('stores', function (Blueprint $table) {
                $table->dropColumn('kind');
            });
        }

        if (Schema::hasTable('branches') && Schema::hasColumn('branches', 'settings')) {
            Schema::table('branches', function (Blueprint $table) {
                $table->dropColumn('settings');
            });
        }
    }
};
