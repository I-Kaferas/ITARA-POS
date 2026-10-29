<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('branch_expenses', 'status')) {
            return;
        }

        Schema::table('branch_expenses', function (Blueprint $table) {
            $table->string('status', 20)->default('paid');
            $table->string('decision', 20)->nullable();
            $table->text('decision_comment')->nullable();
            $table->string('payment_method', 40)->nullable();
            $table->string('payment_reference', 80)->nullable();
            $table->timestamp('decided_at')->nullable();
            $table->timestamp('paid_at')->nullable();
        });
    }

    public function down(): void
    {
        if (! Schema::hasColumn('branch_expenses', 'status')) {
            return;
        }

        Schema::table('branch_expenses', function (Blueprint $table) {
            $table->dropColumn([
                'status',
                'decision',
                'decision_comment',
                'payment_method',
                'payment_reference',
                'decided_at',
                'paid_at',
            ]);
        });
    }
};
