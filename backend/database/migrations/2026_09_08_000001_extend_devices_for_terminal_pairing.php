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
        if (! Schema::hasTable('devices')) {
            return;
        }

        Schema::table('devices', function (Blueprint $table) {
            if (! Schema::hasColumn('devices', 'category')) {
                $table->string('category', 30)->default('pos');
            }
            if (! Schema::hasColumn('devices', 'pos_role')) {
                $table->string('pos_role', 20)->default('standalone');
            }
            if (! Schema::hasColumn('devices', 'master_device_id')) {
                $table->uuid('master_device_id')->nullable();
            }
            if (! Schema::hasColumn('devices', 'master_host')) {
                $table->string('master_host')->nullable();
            }
            if (! Schema::hasColumn('devices', 'platform')) {
                $table->string('platform', 50)->nullable();
            }
            if (! Schema::hasColumn('devices', 'app_version')) {
                $table->string('app_version', 30)->nullable();
            }
            if (! Schema::hasColumn('devices', 'connection_type')) {
                $table->string('connection_type', 20)->nullable();
            }
            if (! Schema::hasColumn('devices', 'ip_address')) {
                $table->string('ip_address', 45)->nullable();
            }
            if (! Schema::hasColumn('devices', 'port')) {
                $table->unsignedSmallInteger('port')->nullable();
            }
            if (! Schema::hasColumn('devices', 'description')) {
                $table->text('description')->nullable();
            }
            if (! Schema::hasColumn('devices', 'registration_status')) {
                $table->string('registration_status', 20)->default('pending');
            }
            if (! Schema::hasColumn('devices', 'sync_token')) {
                $table->string('sync_token', 64)->nullable();
            }
            if (! Schema::hasColumn('devices', 'token_generated_at')) {
                $table->timestamp('token_generated_at')->nullable();
            }
            if (! Schema::hasColumn('devices', 'registered_at')) {
                $table->timestamp('registered_at')->nullable();
            }
        });

        if (! Schema::hasTable('device_warehouse') && Schema::hasTable('warehouses')) {
            Schema::create('device_warehouse', function (Blueprint $table) {
                $table->foreignUuid('device_id')->constrained('devices')->cascadeOnDelete();
                $table->foreignUuid('warehouse_id')->constrained('warehouses')->cascadeOnDelete();
                $table->primary(['device_id', 'warehouse_id']);
            });
        }

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
            if (! Schema::hasIndex('devices', 'devices_sync_token_unique')) {
                $table->unique('sync_token');
            }
            if (! Schema::hasIndex('devices', 'devices_registration_status_index')) {
                $table->index('registration_status');
            }
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
