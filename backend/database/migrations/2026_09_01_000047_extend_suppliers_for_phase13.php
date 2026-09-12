<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('suppliers', function (Blueprint $table) {
            $table->string('legal_name')->nullable()->after('name');
            $table->string('tax_id', 100)->nullable()->after('legal_name');
            $table->jsonb('address')->nullable()->after('phone');
            $table->unsignedSmallInteger('payment_terms_days')->default(30)->after('address');
            $table->bigInteger('credit_limit')->nullable()->after('payment_terms_days');
            $table->string('currency_code', 3)->default('USD')->after('credit_limit');
            $table->text('notes')->nullable()->after('currency_code');
            $table->jsonb('metadata')->nullable()->after('notes');
        });
    }

    public function down(): void
    {
        Schema::table('suppliers', function (Blueprint $table) {
            $table->dropColumn([
                'legal_name',
                'tax_id',
                'address',
                'payment_terms_days',
                'credit_limit',
                'currency_code',
                'notes',
                'metadata',
            ]);
        });
    }
};
