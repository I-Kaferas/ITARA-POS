<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('auth_tokens', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('device_name')->nullable();
            $table->string('access_token_hash', 64)->unique();
            $table->string('refresh_token_hash', 64)->unique();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('access_expires_at');
            $table->timestamp('refresh_expires_at');
            $table->timestamp('revoked_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'revoked_at']);
            $table->index('access_expires_at');
            $table->index('refresh_expires_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('auth_tokens');
    }
};
