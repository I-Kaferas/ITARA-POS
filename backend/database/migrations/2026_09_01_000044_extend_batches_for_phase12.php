<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('batches', function (Blueprint $table) {
            $table->bigInteger('unit_cost')->nullable()->after('expires_at');
            $table->timestamp('received_at')->nullable()->after('unit_cost');

            $table->index(['tenant_id', 'manufactured_at']);
        });
    }

    public function down(): void
    {
        Schema::table('batches', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'manufactured_at']);
            $table->dropColumn(['unit_cost', 'received_at']);
        });
    }
};
