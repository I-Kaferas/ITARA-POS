<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('platform_backup_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('auto_enabled')->default(true);
            $table->string('schedule_time', 5)->default('02:30');
            $table->string('default_type', 20)->default('full');
            $table->unsignedSmallInteger('keep_daily')->default(7);
            $table->unsignedSmallInteger('keep_weekly')->default(4);
            $table->unsignedSmallInteger('keep_monthly')->default(6);
            $table->unsignedInteger('rpo_hours')->default(36);
            $table->unsignedInteger('rto_minutes')->default(120);
            $table->timestamps();
        });

        Schema::create('platform_backups', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('type', 20);
            $table->string('trigger', 20)->default('manual');
            $table->string('status', 20)->default('pending');
            $table->string('disk', 40)->default('local');
            $table->string('path')->nullable();
            $table->unsignedBigInteger('size_bytes')->default(0);
            $table->string('checksum', 64)->nullable();
            $table->json('includes')->nullable();
            $table->json('meta')->nullable();
            $table->text('error_message')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->foreignUuid('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['status', 'finished_at']);
            $table->index(['type', 'trigger']);
            $table->index('expires_at');
        });

        Schema::create('platform_backup_restores', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('backup_id')->constrained('platform_backups')->cascadeOnDelete();
            $table->string('mode', 20)->default('dry_run');
            $table->string('status', 20)->default('pending');
            $table->json('options')->nullable();
            $table->json('report')->nullable();
            $table->text('error_message')->nullable();
            $table->foreignUuid('started_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();

            $table->index(['backup_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('platform_backup_restores');
        Schema::dropIfExists('platform_backups');
        Schema::dropIfExists('platform_backup_settings');
    }
};
