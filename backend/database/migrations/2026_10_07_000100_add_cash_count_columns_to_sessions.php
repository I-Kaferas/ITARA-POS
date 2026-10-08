<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('cash_register_sessions') && ! Schema::hasColumn('cash_register_sessions', 'counted_at')) {
            Schema::table('cash_register_sessions', function (Blueprint $table) {
                $table->timestamp('counted_at')->nullable()->after('actual_cash');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('cash_register_sessions') && Schema::hasColumn('cash_register_sessions', 'counted_at')) {
            Schema::table('cash_register_sessions', function (Blueprint $table) {
                $table->dropColumn('counted_at');
            });
        }
    }
};
