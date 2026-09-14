<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('payment_transactions')) {
            return;
        }

        Schema::table('payment_transactions', function (Blueprint $table) {
            if (! Schema::hasColumn('payment_transactions', 'transaction_type')) {
                $table->string('transaction_type', 20)->default('payment');
            }
            if (! Schema::hasColumn('payment_transactions', 'sale_return_id')) {
                $table->uuid('sale_return_id')->nullable();
            }
            if (! Schema::hasColumn('payment_transactions', 'original_transaction_id')) {
                $table->uuid('original_transaction_id')->nullable();
            }
        });

        Schema::table('payment_transactions', function (Blueprint $table) {
            $table->index(['tenant_id', 'transaction_type']);
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('payment_transactions')) {
            return;
        }

        Schema::table('payment_transactions', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'transaction_type']);
            $table->dropColumn(['transaction_type', 'sale_return_id', 'original_transaction_id']);
        });
    }
};
