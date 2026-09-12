<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->string('trade_name')->nullable()->after('name');
            $table->string('legal_form', 50)->nullable()->after('legal_name');
            $table->string('registration_number', 100)->nullable()->after('tax_id');
            $table->string('phone', 50)->nullable()->after('registration_number');
            $table->string('email')->nullable()->after('phone');
            $table->string('website')->nullable()->after('email');
            $table->string('logo_url')->nullable()->after('website');
        });

        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE companies ALTER COLUMN currency_code SET DEFAULT 'FBU'");
        }
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE companies ALTER COLUMN currency_code SET DEFAULT 'USD'");
        }

        Schema::table('companies', function (Blueprint $table) {
            $table->dropColumn([
                'trade_name',
                'legal_form',
                'registration_number',
                'phone',
                'email',
                'website',
                'logo_url',
            ]);
        });
    }
};
