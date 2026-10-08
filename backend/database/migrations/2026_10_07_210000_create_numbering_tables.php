<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('numbering_rules', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('branch_id')->nullable()->constrained('branches')->cascadeOnDelete();
            $table->string('scope_key', 40);
            $table->string('document_type', 40);
            $table->string('prefix', 20);
            $table->string('pattern', 80)->default('{prefix}-{year}-{sequence}');
            $table->unsignedTinyInteger('padding')->default(6);
            $table->string('reset_policy', 20)->default('yearly');
            $table->unsignedInteger('starting_number')->default(1);
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['tenant_id', 'scope_key', 'document_type'], 'numbering_rules_scope_unique');
            $table->index(['tenant_id', 'document_type']);
        });

        Schema::create('numbering_sequences', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('branch_id')->nullable()->constrained('branches')->cascadeOnDelete();
            $table->string('scope_key', 40);
            $table->string('document_type', 40);
            $table->string('period_key', 20)->default('');
            $table->unsignedBigInteger('last_value')->default(0);
            $table->timestamps();

            $table->unique(
                ['tenant_id', 'scope_key', 'document_type', 'period_key'],
                'numbering_sequences_scope_unique'
            );
        });

        if (Schema::hasTable('branch_expenses') && ! Schema::hasColumn('branch_expenses', 'reference')) {
            Schema::table('branch_expenses', function (Blueprint $table) {
                $table->string('reference', 40)->nullable()->after('id');
                $table->unique(['tenant_id', 'reference'], 'branch_expenses_tenant_reference_unique');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('branch_expenses') && Schema::hasColumn('branch_expenses', 'reference')) {
            Schema::table('branch_expenses', function (Blueprint $table) {
                $table->dropUnique('branch_expenses_tenant_reference_unique');
                $table->dropColumn('reference');
            });
        }

        Schema::dropIfExists('numbering_sequences');
        Schema::dropIfExists('numbering_rules');
    }
};
