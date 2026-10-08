<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('crm_accounts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('name');
            $table->string('legal_name')->nullable();
            $table->string('email')->nullable();
            $table->string('phone', 50)->nullable();
            $table->string('website')->nullable();
            $table->string('tax_id', 100)->nullable();
            $table->string('industry', 80)->nullable();
            $table->json('address')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['tenant_id', 'name']);
        });

        Schema::table('customers', function (Blueprint $table) {
            $table->string('crm_role', 20)->default('client');
            $table->string('job_title', 120)->nullable();
            $table->foreignUuid('crm_account_id')->nullable()->constrained('crm_accounts')->nullOnDelete();
            $table->index(['tenant_id', 'crm_role']);
        });

        Schema::create('crm_leads', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->foreignUuid('crm_account_id')->nullable()->constrained('crm_accounts')->nullOnDelete();
            $table->string('name');
            $table->string('email')->nullable();
            $table->string('phone', 50)->nullable();
            $table->string('company_name')->nullable();
            $table->string('source', 40)->default('manual');
            $table->string('status', 20)->default('new');
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'status']);
        });

        Schema::create('crm_pipeline_stages', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('name');
            $table->unsignedSmallInteger('position')->default(0);
            $table->unsignedTinyInteger('probability')->default(0);
            $table->boolean('is_won')->default(false);
            $table->boolean('is_lost')->default(false);
            $table->timestamps();

            $table->unique(['tenant_id', 'name']);
            $table->index(['tenant_id', 'position']);
        });

        Schema::create('crm_opportunities', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->foreignUuid('crm_account_id')->nullable()->constrained('crm_accounts')->nullOnDelete();
            $table->foreignUuid('stage_id')->constrained('crm_pipeline_stages')->cascadeOnDelete();
            $table->string('title');
            $table->unsignedBigInteger('amount')->default(0);
            $table->date('expected_close_on')->nullable();
            $table->string('status', 20)->default('open');
            $table->timestamps();

            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'stage_id']);
        });

        Schema::create('crm_activities', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->foreignUuid('lead_id')->nullable()->constrained('crm_leads')->nullOnDelete();
            $table->foreignUuid('opportunity_id')->nullable()->constrained('crm_opportunities')->nullOnDelete();
            $table->string('type', 20);
            $table->string('subject');
            $table->text('body')->nullable();
            $table->string('direction', 20)->nullable();
            $table->string('status', 20)->default('open');
            $table->timestamp('due_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'type']);
            $table->index(['tenant_id', 'customer_id']);
        });

        Schema::create('crm_campaigns', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('name');
            $table->string('channel', 20)->default('email');
            $table->string('status', 20)->default('draft');
            $table->date('starts_on')->nullable();
            $table->date('ends_on')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'status']);
        });

        Schema::create('crm_campaign_members', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('campaign_id')->constrained('crm_campaigns')->cascadeOnDelete();
            $table->foreignUuid('customer_id')->constrained('customers')->cascadeOnDelete();
            $table->string('status', 20)->default('subscribed');
            $table->timestamps();

            $table->unique(['campaign_id', 'customer_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('crm_campaign_members');
        Schema::dropIfExists('crm_campaigns');
        Schema::dropIfExists('crm_activities');
        Schema::dropIfExists('crm_opportunities');
        Schema::dropIfExists('crm_pipeline_stages');
        Schema::dropIfExists('crm_leads');

        Schema::table('customers', function (Blueprint $table) {
            $table->dropConstrainedForeignId('crm_account_id');
            $table->dropIndex(['tenant_id', 'crm_role']);
            $table->dropColumn(['crm_role', 'job_title']);
        });

        Schema::dropIfExists('crm_accounts');
    }
};
