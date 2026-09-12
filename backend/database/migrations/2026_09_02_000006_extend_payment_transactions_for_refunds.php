<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payment_transactions', function (Blueprint $table) {
            $table->string('transaction_type', 20)->default('payment')->after('transaction_number');
            $table->foreignUuid('sale_return_id')->nullable()->after('sale_id')->constrained('sale_returns')->nullOnDelete();
            $table->foreignUuid('original_transaction_id')->nullable()->after('sale_return_id')
                ->constrained('payment_transactions')->nullOnDelete();

            $table->index(['tenant_id', 'transaction_type']);
        });
    }

    public function down(): void
    {
        Schema::table('payment_transactions', function (Blueprint $table) {
            $table->dropForeign(['sale_return_id']);
            $table->dropForeign(['original_transaction_id']);
            $table->dropIndex(['tenant_id', 'transaction_type']);
            $table->dropColumn(['transaction_type', 'sale_return_id', 'original_transaction_id']);
        });
    }
};
