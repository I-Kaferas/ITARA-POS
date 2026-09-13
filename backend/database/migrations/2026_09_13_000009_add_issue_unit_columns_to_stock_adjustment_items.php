<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_adjustment_items', function (Blueprint $table) {
            $table->foreignUuid('sale_unit_id')->nullable()->constrained('product_sale_units')->nullOnDelete();
            $table->unsignedInteger('entered_quantity')->nullable();
            $table->string('unit_name', 80)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('stock_adjustment_items', function (Blueprint $table) {
            $table->dropConstrainedForeignId('sale_unit_id');
            $table->dropColumn(['entered_quantity', 'unit_name']);
        });
    }
};
