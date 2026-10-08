<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inbox_notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('event', 40);
            $table->string('title');
            $table->text('body');
            $table->json('context')->nullable();
            $table->string('fingerprint', 191);
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'fingerprint']);
            $table->index(['tenant_id', 'user_id', 'read_at']);
            $table->index(['tenant_id', 'event']);
        });

        Schema::create('notification_preferences', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->cascadeOnDelete();
            $table->string('scope_key', 64);
            $table->string('event', 40);
            $table->json('channels');
            $table->timestamps();

            $table->unique(['tenant_id', 'scope_key', 'event']);
        });

        Schema::create('notification_channel_settings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('channel', 32);
            $table->boolean('enabled')->default(false);
            $table->text('config')->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'channel']);
        });

        Schema::create('notification_deliveries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('event', 40);
            $table->string('channel', 32);
            $table->string('status', 20);
            $table->string('recipient')->nullable();
            $table->string('title');
            $table->text('body');
            $table->string('fingerprint', 191);
            $table->text('error')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'created_at']);
            $table->index(['user_id', 'channel', 'fingerprint']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('push_subscriptions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('token', 512);
            $table->string('platform', 20);
            $table->timestamps();

            $table->unique(['user_id', 'token']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('push_subscriptions');
        Schema::dropIfExists('notification_deliveries');
        Schema::dropIfExists('notification_channel_settings');
        Schema::dropIfExists('notification_preferences');
        Schema::dropIfExists('inbox_notifications');
    }
};
