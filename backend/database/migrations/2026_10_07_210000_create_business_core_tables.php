<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('parties', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('kind', 20)->default('person');
            $table->string('display_name');
            $table->string('legal_name')->nullable();
            $table->string('code', 50)->nullable();
            $table->string('email')->nullable();
            $table->string('phone', 50)->nullable();
            $table->string('tax_id', 100)->nullable();
            $table->json('address')->nullable();
            $table->text('notes')->nullable();
            $table->json('metadata')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'kind']);
            $table->index(['tenant_id', 'email']);
            $table->index(['tenant_id', 'phone']);
            $table->index(['tenant_id', 'tax_id']);
            $table->index(['tenant_id', 'display_name']);
        });

        Schema::create('locations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('parent_id')->nullable()->constrained('locations')->nullOnDelete();
            $table->string('type', 40);
            $table->string('name');
            $table->string('code', 50)->nullable();
            $table->json('address')->nullable();
            $table->json('geo')->nullable();
            $table->json('metadata')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'type']);
            $table->index(['tenant_id', 'name']);
        });

        Schema::create('employees', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('party_id')->constrained('parties')->cascadeOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('code', 50)->nullable();
            $table->string('job_title', 120)->nullable();
            $table->string('department', 120)->nullable();
            $table->date('hired_on')->nullable();
            $table->date('terminated_on')->nullable();
            $table->json('metadata')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'party_id']);
            $table->unique(['tenant_id', 'code']);
            $table->unique(['tenant_id', 'user_id']);
            $table->index(['tenant_id', 'is_active']);
        });

        Schema::create('business_documents', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('party_id')->nullable()->constrained('parties')->nullOnDelete();
            $table->foreignUuid('location_id')->nullable()->constrained('locations')->nullOnDelete();
            $table->string('kind', 40);
            $table->string('number', 80)->nullable();
            $table->string('status', 40)->default('draft');
            $table->nullableUuidMorphs('source');
            $table->json('payload')->nullable();
            $table->timestamp('issued_at')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'kind', 'status']);
            $table->index(['tenant_id', 'party_id']);
        });

        Schema::create('party_contexts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('party_id')->constrained('parties')->cascadeOnDelete();
            $table->string('context', 40);
            $table->string('label')->nullable();
            $table->json('metadata')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['party_id', 'context']);
            $table->index(['tenant_id', 'context']);
        });

        Schema::table('customers', function (Blueprint $table) {
            $table->foreignUuid('party_id')->nullable()->after('tenant_id')->constrained('parties')->nullOnDelete();
            $table->unique('party_id');
        });

        Schema::table('suppliers', function (Blueprint $table) {
            $table->foreignUuid('party_id')->nullable()->after('tenant_id')->constrained('parties')->nullOnDelete();
            $table->unique('party_id');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->foreignUuid('party_id')->nullable()->after('tenant_id')->constrained('parties')->nullOnDelete();
            $table->unique('party_id');
        });

        Schema::table('crm_accounts', function (Blueprint $table) {
            $table->foreignUuid('party_id')->nullable()->after('tenant_id')->constrained('parties')->nullOnDelete();
            $table->unique('party_id');
        });

        Schema::table('companies', function (Blueprint $table) {
            $table->foreignUuid('party_id')->nullable()->after('tenant_id')->constrained('parties')->nullOnDelete();
            $table->unique('party_id');
        });

        Schema::table('branches', function (Blueprint $table) {
            $table->foreignUuid('location_id')->nullable()->after('company_id')->constrained('locations')->nullOnDelete();
        });

        Schema::table('stores', function (Blueprint $table) {
            $table->foreignUuid('location_id')->nullable()->after('branch_id')->constrained('locations')->nullOnDelete();
        });

        Schema::table('warehouses', function (Blueprint $table) {
            $table->foreignUuid('location_id')->nullable()->after('branch_id')->constrained('locations')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('warehouses', function (Blueprint $table) {
            $table->dropConstrainedForeignId('location_id');
        });
        Schema::table('stores', function (Blueprint $table) {
            $table->dropConstrainedForeignId('location_id');
        });
        Schema::table('branches', function (Blueprint $table) {
            $table->dropConstrainedForeignId('location_id');
        });
        Schema::table('companies', function (Blueprint $table) {
            $table->dropConstrainedForeignId('party_id');
        });
        Schema::table('crm_accounts', function (Blueprint $table) {
            $table->dropConstrainedForeignId('party_id');
        });
        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('party_id');
        });
        Schema::table('suppliers', function (Blueprint $table) {
            $table->dropConstrainedForeignId('party_id');
        });
        Schema::table('customers', function (Blueprint $table) {
            $table->dropConstrainedForeignId('party_id');
        });

        Schema::dropIfExists('party_contexts');
        Schema::dropIfExists('business_documents');
        Schema::dropIfExists('employees');
        Schema::dropIfExists('locations');
        Schema::dropIfExists('parties');
    }
};
