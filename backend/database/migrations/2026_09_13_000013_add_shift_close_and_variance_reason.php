<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('cashier_shifts')) {
            Schema::table('cashier_shifts', function (Blueprint $table) {
                if (! Schema::hasColumn('cashier_shifts', 'sales_total')) {
                    $table->bigInteger('sales_total')->default(0)->after('opening_balance');
                }
                if (! Schema::hasColumn('cashier_shifts', 'refunds_total')) {
                    $table->bigInteger('refunds_total')->default(0)->after('sales_total');
                }
                if (! Schema::hasColumn('cashier_shifts', 'discounts_total')) {
                    $table->bigInteger('discounts_total')->default(0)->after('refunds_total');
                }
                if (! Schema::hasColumn('cashier_shifts', 'cash_in_total')) {
                    $table->bigInteger('cash_in_total')->default(0)->after('discounts_total');
                }
                if (! Schema::hasColumn('cashier_shifts', 'cash_out_total')) {
                    $table->bigInteger('cash_out_total')->default(0)->after('cash_in_total');
                }
                if (! Schema::hasColumn('cashier_shifts', 'expenses_total')) {
                    $table->bigInteger('expenses_total')->default(0)->after('cash_out_total');
                }
                if (! Schema::hasColumn('cashier_shifts', 'actual_cash')) {
                    $table->bigInteger('actual_cash')->nullable()->after('expected_cash');
                }
                if (! Schema::hasColumn('cashier_shifts', 'variance')) {
                    $table->bigInteger('variance')->nullable()->after('actual_cash');
                }
                if (! Schema::hasColumn('cashier_shifts', 'variance_reason')) {
                    $table->text('variance_reason')->nullable()->after('variance');
                }
                if (! Schema::hasColumn('cashier_shifts', 'closing_notes')) {
                    $table->text('closing_notes')->nullable()->after('opening_notes');
                }
                if (! Schema::hasColumn('cashier_shifts', 'closed_at')) {
                    $table->timestamp('closed_at')->nullable()->after('opened_at');
                }
            });
        }

        if (Schema::hasTable('cash_register_sessions') && ! Schema::hasColumn('cash_register_sessions', 'variance_reason')) {
            Schema::table('cash_register_sessions', function (Blueprint $table) {
                $table->text('variance_reason')->nullable()->after('variance');
            });
        }

        if (Schema::hasTable('company_payment_methods')) {
            \Illuminate\Support\Facades\DB::table('company_payment_methods')
                ->whereIn('code', ['bank_transfer', 'credit'])
                ->where('is_enabled', true)
                ->update(['available_on_pos' => true]);
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('cash_register_sessions') && Schema::hasColumn('cash_register_sessions', 'variance_reason')) {
            Schema::table('cash_register_sessions', function (Blueprint $table) {
                $table->dropColumn('variance_reason');
            });
        }
    }
};
