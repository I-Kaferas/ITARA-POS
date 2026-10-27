<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('recurring_expenses', function (Blueprint $table) {
            if (! Schema::hasColumn('recurring_expenses', 'fund_source')) {
                $table->string('fund_source', 20)->default('main');
            }
            if (! Schema::hasColumn('recurring_expenses', 'user_id')) {
                $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            }
            if (! Schema::hasColumn('recurring_expenses', 'starts_on')) {
                $table->date('starts_on')->nullable();
            }
            if (! Schema::hasColumn('recurring_expenses', 'ends_on')) {
                $table->date('ends_on')->nullable();
            }
            if (! Schema::hasColumn('recurring_expenses', 'notes')) {
                $table->text('notes')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('recurring_expenses', function (Blueprint $table) {
            if (Schema::hasColumn('recurring_expenses', 'user_id')) {
                $table->dropForeign(['user_id']);
                $table->dropColumn('user_id');
            }
            foreach (['notes', 'ends_on', 'starts_on', 'fund_source'] as $column) {
                if (Schema::hasColumn('recurring_expenses', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
