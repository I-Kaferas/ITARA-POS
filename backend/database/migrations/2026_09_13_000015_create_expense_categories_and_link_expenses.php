<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('expense_categories')) {
            Schema::create('expense_categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('code', 40);
            $table->string('name');
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();

            $table->unique(['tenant_id', 'code']);
        });
        }

        if (Schema::hasTable('branch_expenses')) {
            Schema::table('branch_expenses', function (Blueprint $table) {
                if (! Schema::hasColumn('branch_expenses', 'expense_category_id')) {
                    $table->uuid('expense_category_id')->nullable();
                }
                if (! Schema::hasColumn('branch_expenses', 'cash_register_session_id')) {
                    $table->uuid('cash_register_session_id')->nullable();
                }
                if (! Schema::hasColumn('branch_expenses', 'user_id')) {
                    $table->uuid('user_id')->nullable();
                }
                if (! Schema::hasColumn('branch_expenses', 'recorded_by')) {
                    $table->uuid('recorded_by')->nullable();
                }
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('branch_expenses')) {
            Schema::table('branch_expenses', function (Blueprint $table) {
                foreach (['recorded_by', 'user_id', 'cash_register_session_id', 'expense_category_id'] as $column) {
                    if (Schema::hasColumn('branch_expenses', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }

        Schema::dropIfExists('expense_categories');
    }
};
