<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_counts', function (Blueprint $table) {
            $table->string('count_type', 30)->default('full')->after('warehouse_id');
            $table->date('counted_at')->nullable()->after('count_type');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_counts', function (Blueprint $table) {
            $table->dropColumn(['count_type', 'counted_at']);
        });
    }
};
