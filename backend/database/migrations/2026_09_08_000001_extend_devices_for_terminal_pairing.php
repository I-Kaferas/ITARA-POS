<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('devices', function (Blueprint $table) {
            $table->string('category', 30)->default('pos')->after('device_type');
            $table->string('connection_type', 20)->nullable()->after('master_host');
            $table->string('ip_address', 45)->nullable()->after('connection_type');
            $table->unsignedSmallInteger('port')->nullable()->after('ip_address');
            $table->text('description')->nullable()->after('port');
            $table->string('registration_status', 20)->default('pending')->after('description');
            $table->string('sync_token', 64)->nullable()->after('registration_status');
            $table->timestamp('token_generated_at')->nullable()->after('sync_token');
            $table->timestamp('registered_at')->nullable()->after('token_generated_at');
        });

        Schema::create('device_warehouse', function (Blueprint $table) {
            $table->foreignUuid('device_id')->constrained('devices')->cascadeOnDelete();
            $table->foreignUuid('warehouse_id')->constrained('warehouses')->cascadeOnDelete();
            $table->primary(['device_id', 'warehouse_id']);
        });

        DB::table('devices')->orderBy('id')->each(function (object $device): void {
            $category = in_array($device->device_type, ['pos', 'printer', 'tablet', 'computer', 'other'], true)
                ? $device->device_type
                : 'other';

            DB::table('devices')->where('id', $device->id)->update([
                'category' => $category,
                'sync_token' => Str::lower(Str::random(32)),
                'token_generated_at' => now(),
                'registration_status' => $device->last_sync_at ? 'registered' : 'pending',
                'registered_at' => $device->last_sync_at,
            ]);
        });

        Schema::table('devices', function (Blueprint $table) {
            $table->unique('sync_token');
            $table->index('registration_status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_warehouse');

        Schema::table('devices', function (Blueprint $table) {
            $table->dropUnique(['sync_token']);
            $table->dropIndex(['registration_status']);
            $table->dropColumn([
                'category',
                'connection_type',
                'ip_address',
                'port',
                'description',
                'registration_status',
                'sync_token',
                'token_generated_at',
                'registered_at',
            ]);
        });
    }
};
