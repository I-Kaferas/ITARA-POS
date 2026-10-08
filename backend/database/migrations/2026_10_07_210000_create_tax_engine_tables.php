<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('taxes', function (Blueprint $table) {
            $table->string('kind', 32)->default('vat')->after('code');
            $table->string('type', 32)->default('percentage')->after('kind');
            $table->unsignedInteger('priority')->default(1)->after('rate');
            $table->char('country', 2)->nullable()->after('priority');
            $table->string('region', 120)->nullable()->after('country');
            $table->boolean('is_compound')->default(false)->after('is_inclusive');
            $table->text('description')->nullable()->after('is_active');

            $table->index(['tenant_id', 'kind']);
            $table->index(['tenant_id', 'country']);
        });

        // Existing Burundi-style defaults: TVA → vat, EXO → exempt.
        if (Schema::hasTable('taxes')) {
            DB::table('taxes')->where('code', 'like', 'TVA%')->where('kind', 'vat')->update(['kind' => 'vat']);
            DB::table('taxes')->whereIn('code', ['EXO', 'EXEMPT', 'EXONERE'])->update(['kind' => 'exempt']);
            DB::table('taxes')->whereIn('code', ['TVA0', 'ZERO', 'ZERO_RATED'])->update(['kind' => 'zero_rated']);
        }

        Schema::create('tax_groups', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('name');
            $table->string('code', 50);
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'is_active']);
        });

        Schema::create('tax_group_tax', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tax_group_id')->constrained('tax_groups')->cascadeOnDelete();
            $table->foreignUuid('tax_id')->constrained('taxes')->cascadeOnDelete();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->unique(['tax_group_id', 'tax_id']);
        });

        Schema::create('tax_classes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('name');
            $table->string('code', 50);
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'is_active']);
        });

        Schema::create('tax_rules', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('name');
            $table->foreignUuid('tax_class_id')->nullable()->constrained('tax_classes')->nullOnDelete();
            $table->foreignUuid('tax_id')->nullable()->constrained('taxes')->nullOnDelete();
            $table->foreignUuid('tax_group_id')->nullable()->constrained('tax_groups')->nullOnDelete();
            $table->char('country', 2)->nullable();
            $table->string('region', 120)->nullable();
            $table->unsignedInteger('priority')->default(1);
            $table->boolean('is_active')->default(true);
            $table->text('description')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['tenant_id', 'is_active', 'priority']);
            $table->index(['tenant_id', 'tax_class_id', 'country']);
        });

        if (Schema::hasTable('products') && ! Schema::hasColumn('products', 'tax_class_id')) {
            Schema::table('products', function (Blueprint $table) {
                $table->foreignUuid('tax_class_id')->nullable()->after('tax_id')->constrained('tax_classes')->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('products') && Schema::hasColumn('products', 'tax_class_id')) {
            Schema::table('products', function (Blueprint $table) {
                $table->dropConstrainedForeignId('tax_class_id');
            });
        }

        Schema::dropIfExists('tax_rules');
        Schema::dropIfExists('tax_group_tax');
        Schema::dropIfExists('tax_classes');
        Schema::dropIfExists('tax_groups');

        Schema::table('taxes', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'kind']);
            $table->dropIndex(['tenant_id', 'country']);
            $table->dropColumn([
                'kind',
                'type',
                'priority',
                'country',
                'region',
                'is_compound',
                'description',
            ]);
        });
    }
};
