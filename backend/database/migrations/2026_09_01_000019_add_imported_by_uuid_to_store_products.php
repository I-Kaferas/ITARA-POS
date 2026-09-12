<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('store_products', function (Blueprint $table) {
            $table->foreignUuid('imported_by')->nullable()->after('imported_at')->constrained('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('store_products', function (Blueprint $table) {
            $table->dropForeign(['imported_by']);
            $table->dropColumn('imported_by');
        });
    }
};
