<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('currency_exchange_rates')) {
            Schema::create('currency_exchange_rates', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
                $table->foreignUuid('currency_id')->constrained('currencies')->cascadeOnDelete();
                $table->char('currency_code', 3);
                $table->decimal('rate', 18, 8);
                $table->decimal('previous_rate', 18, 8)->nullable();
                $table->char('base_currency_code', 3);
                $table->timestamp('effective_at');
                $table->foreignUuid('changed_by')->nullable()->constrained('users')->nullOnDelete();
                $table->string('source', 40)->default('manual');
                $table->string('note')->nullable();
                $table->timestamps();

                $table->index(['tenant_id', 'currency_code', 'effective_at']);
                $table->index(['tenant_id', 'currency_id', 'effective_at']);
            });
        }

        if (Schema::hasTable('sale_payments')) {
            Schema::table('sale_payments', function (Blueprint $table) {
                if (! Schema::hasColumn('sale_payments', 'amount_in_sale_currency')) {
                    $table->bigInteger('amount_in_sale_currency')->nullable()->after('amount');
                }
                if (! Schema::hasColumn('sale_payments', 'exchange_rate')) {
                    $table->decimal('exchange_rate', 18, 8)->nullable()->after('amount_in_sale_currency');
                }
                if (! Schema::hasColumn('sale_payments', 'sale_currency')) {
                    $table->char('sale_currency', 3)->nullable()->after('exchange_rate');
                }
            });
        }

        if (Schema::hasTable('payment_transactions')) {
            Schema::table('payment_transactions', function (Blueprint $table) {
                if (! Schema::hasColumn('payment_transactions', 'amount_in_sale_currency')) {
                    $table->bigInteger('amount_in_sale_currency')->nullable()->after('amount');
                }
                if (! Schema::hasColumn('payment_transactions', 'exchange_rate')) {
                    $table->decimal('exchange_rate', 18, 8)->nullable()->after('amount_in_sale_currency');
                }
                if (! Schema::hasColumn('payment_transactions', 'sale_currency')) {
                    $table->char('sale_currency', 3)->nullable()->after('exchange_rate');
                }
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('payment_transactions')) {
            Schema::table('payment_transactions', function (Blueprint $table) {
                foreach (['amount_in_sale_currency', 'exchange_rate', 'sale_currency'] as $column) {
                    if (Schema::hasColumn('payment_transactions', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }

        if (Schema::hasTable('sale_payments')) {
            Schema::table('sale_payments', function (Blueprint $table) {
                foreach (['amount_in_sale_currency', 'exchange_rate', 'sale_currency'] as $column) {
                    if (Schema::hasColumn('sale_payments', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }

        Schema::dropIfExists('currency_exchange_rates');
    }
};
