<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('purchases', function (Blueprint $table) {
            $table->date('due_date')->nullable()->after('total');
            $table->text('notes')->nullable()->after('due_date');

            $table->index(['tenant_id', 'due_date']);
        });
    }

    public function down(): void
    {
        Schema::table('purchases', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'due_date']);
            $table->dropColumn(['due_date', 'notes']);
        });
    }
};
