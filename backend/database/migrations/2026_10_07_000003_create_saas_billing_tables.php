<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('saas_plans', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('code', 40)->unique();
            $table->string('name');
            $table->unsignedSmallInteger('rank');
            $table->unsignedInteger('monthly_price')->default(0);
            $table->unsignedInteger('yearly_price')->default(0);
            $table->char('currency_code', 3)->default('USD');
            $table->unsignedSmallInteger('trial_days')->default(14);
            $table->unsignedSmallInteger('grace_days')->default(7);
            $table->json('limits');
            $table->boolean('is_public')->default(true);
            $table->timestamps();
        });

        Schema::create('saas_subscriptions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->unique()->constrained('tenants')->cascadeOnDelete();
            $table->string('plan_code', 40);
            $table->string('status', 20)->default('trial');
            $table->string('billing_cycle', 20)->default('yearly');
            $table->date('trial_ends_on')->nullable();
            $table->date('period_starts_on')->nullable();
            $table->date('period_ends_on')->nullable();
            $table->date('grace_ends_on')->nullable();
            $table->string('pending_plan_code', 40)->nullable();
            $table->string('pending_billing_cycle', 20)->nullable();
            $table->timestamp('suspended_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index('plan_code');
        });

        Schema::create('saas_invoices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('subscription_id')->constrained('saas_subscriptions')->cascadeOnDelete();
            $table->string('number', 40)->unique();
            $table->string('kind', 20);
            $table->string('status', 20)->default('open');
            $table->string('plan_code', 40);
            $table->string('billing_cycle', 20);
            $table->unsignedInteger('amount')->default(0);
            $table->char('currency_code', 3)->default('USD');
            $table->date('period_starts_on')->nullable();
            $table->date('period_ends_on')->nullable();
            $table->date('issued_on');
            $table->date('due_on');
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'status']);
            $table->index(['subscription_id', 'kind']);
        });

        Schema::create('saas_payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('invoice_id')->constrained('saas_invoices')->cascadeOnDelete();
            $table->unsignedInteger('amount')->default(0);
            $table->char('currency_code', 3)->default('USD');
            $table->string('method', 30)->default('manual');
            $table->string('reference', 120)->nullable();
            $table->string('status', 20)->default('pending');
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index(['invoice_id', 'status']);
        });

        Schema::create('saas_subscription_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('subscription_id')->constrained('saas_subscriptions')->cascadeOnDelete();
            $table->string('type', 40);
            $table->json('payload')->nullable();
            $table->uuid('actor_id')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['subscription_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('saas_subscription_events');
        Schema::dropIfExists('saas_payments');
        Schema::dropIfExists('saas_invoices');
        Schema::dropIfExists('saas_subscriptions');
        Schema::dropIfExists('saas_plans');
    }
};
