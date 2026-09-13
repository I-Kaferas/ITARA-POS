<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_counts', function (Blueprint $table) {
            $table->string('zone', 120)->nullable()->after('counted_at');
            $table->foreignUuid('category_id')->nullable()->after('zone')->constrained('categories')->nullOnDelete();
            $table->boolean('lock_movements')->default(false)->after('category_id');
            $table->foreignUuid('approved_by')->nullable()->after('confirmed_at')->constrained('users')->nullOnDelete();
            $table->timestamp('started_at')->nullable()->after('completed_at');
            $table->timestamp('submitted_at')->nullable()->after('started_at');
            $table->timestamp('reviewed_at')->nullable()->after('submitted_at');
            $table->timestamp('cancelled_at')->nullable()->after('reviewed_at');
            $table->foreignUuid('cancelled_by')->nullable()->after('cancelled_at')->constrained('users')->nullOnDelete();
        });

        Schema::table('inventory_count_items', function (Blueprint $table) {
            $table->foreignUuid('sale_unit_id')->nullable()->after('product_variant_id')->constrained('product_sale_units')->nullOnDelete();
            $table->integer('entered_quantity')->nullable()->after('counted_quantity');
            $table->string('unit_name', 80)->nullable()->after('entered_quantity');
            $table->unsignedInteger('unit_volume_ml')->nullable()->after('unit_name');
            $table->unsignedInteger('remainder_ml')->nullable()->after('unit_volume_ml');
            $table->integer('unit_cost')->nullable()->after('remainder_ml');
            $table->integer('line_value')->nullable()->after('unit_cost');
            $table->string('variance_reason', 40)->nullable()->after('line_value');
            $table->string('notes')->nullable()->after('variance_reason');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_count_items', function (Blueprint $table) {
            $table->dropConstrainedForeignId('sale_unit_id');
            $table->dropColumn([
                'entered_quantity',
                'unit_name',
                'unit_volume_ml',
                'remainder_ml',
                'unit_cost',
                'line_value',
                'variance_reason',
                'notes',
            ]);
        });

        Schema::table('inventory_counts', function (Blueprint $table) {
            $table->dropConstrainedForeignId('category_id');
            $table->dropConstrainedForeignId('approved_by');
            $table->dropConstrainedForeignId('cancelled_by');
            $table->dropColumn([
                'zone',
                'lock_movements',
                'started_at',
                'submitted_at',
                'reviewed_at',
                'cancelled_at',
            ]);
        });
    }
};
