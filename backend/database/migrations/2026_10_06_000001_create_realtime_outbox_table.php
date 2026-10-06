<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('realtime_outbox', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->uuid('store_id')->nullable();
            $table->uuid('user_id')->nullable();
            $table->string('event_name', 80);
            $table->string('entity_type', 40)->nullable();
            $table->uuid('entity_id')->nullable();
            $table->string('status', 40)->nullable();
            $table->json('payload');
            $table->timestamp('occurred_at');
            $table->timestamp('broadcast_at')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'occurred_at']);
            $table->index(['tenant_id', 'broadcast_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('realtime_outbox');
    }
};
