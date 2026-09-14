<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sync_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('device_id')->nullable()->constrained('devices')->nullOnDelete();
            $table->unsignedBigInteger('sequence');
            $table->string('event_type', 40);
            $table->string('entity_type', 40);
            $table->uuid('entity_id');
            $table->json('payload');
            $table->timestamp('occurred_at');
            $table->timestamp('created_at')->nullable();

            $table->unique(['tenant_id', 'sequence']);
            $table->index(['store_id', 'sequence']);
            $table->index(['entity_type', 'entity_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_events');
    }
};
