<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->string('code', 50)->nullable()->after('tenant_id');
            $table->string('company_name')->nullable()->after('name');
            $table->string('tax_id', 100)->nullable()->after('company_name');
            $table->date('date_of_birth')->nullable()->after('phone');
            $table->string('gender', 20)->nullable()->after('date_of_birth');
            $table->unsignedBigInteger('credit_limit')->nullable()->after('gender');
            $table->unsignedSmallInteger('payment_terms_days')->default(0)->after('credit_limit');
            $table->unsignedBigInteger('loyalty_points')->default(0)->after('payment_terms_days');
            $table->string('loyalty_tier', 30)->default('standard')->after('loyalty_points');
            $table->text('notes')->nullable()->after('loyalty_tier');
            $table->jsonb('metadata')->nullable()->after('notes');

            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'loyalty_tier']);
        });
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->dropUnique(['tenant_id', 'code']);
            $table->dropIndex(['tenant_id', 'loyalty_tier']);
            $table->dropColumn([
                'code',
                'company_name',
                'tax_id',
                'date_of_birth',
                'gender',
                'credit_limit',
                'payment_terms_days',
                'loyalty_points',
                'loyalty_tier',
                'notes',
                'metadata',
            ]);
        });
    }
};
