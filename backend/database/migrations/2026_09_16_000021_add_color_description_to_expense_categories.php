<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('expense_categories')) {
            return;
        }

        Schema::table('expense_categories', function (Blueprint $table) {
            if (! Schema::hasColumn('expense_categories', 'color')) {
                $table->string('color', 7)->default('#6366F1')->after('name');
            }
            if (! Schema::hasColumn('expense_categories', 'description')) {
                $table->string('description', 500)->nullable()->after('color');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('expense_categories')) {
            return;
        }

        Schema::table('expense_categories', function (Blueprint $table) {
            foreach (['description', 'color'] as $column) {
                if (Schema::hasColumn('expense_categories', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
