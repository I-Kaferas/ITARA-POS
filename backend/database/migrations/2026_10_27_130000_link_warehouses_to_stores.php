<?php

use App\Services\Inventory\StoreStockLocation;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouses', function (Blueprint $table) {
            $table->uuid('store_id')->nullable();
            $table->unique('store_id');
            $table->foreign('store_id')->references('id')->on('stores')->nullOnDelete();
        });

        app(StoreStockLocation::class)->attachAll();
    }

    public function down(): void
    {
        Schema::table('warehouses', function (Blueprint $table) {
            $table->dropForeign(['store_id']);
            $table->dropUnique(['store_id']);
            $table->dropColumn('store_id');
        });
    }
};
