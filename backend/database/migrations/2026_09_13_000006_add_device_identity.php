<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('devices')) {
            return;
        }

        Schema::table('devices', function (Blueprint $table) {
            if (! Schema::hasColumn('devices', 'code')) {
                $table->string('code', 20)->nullable();
            }
            if (! Schema::hasColumn('devices', 'user_id')) {
                $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            }
            if (! Schema::hasColumn('devices', 'branch_id')) {
                $table->foreignUuid('branch_id')->nullable()->constrained('branches')->nullOnDelete();
            }
            if (! Schema::hasColumn('devices', 'local_server')) {
                $table->string('local_server')->nullable();
            }
            if (! Schema::hasColumn('devices', 'status')) {
                $table->string('status', 20)->default('pending');
            }
            if (! Schema::hasColumn('devices', 'revoked_at')) {
                $table->timestamp('revoked_at')->nullable();
            }
        });

        $sequence = 1;
        foreach (DB::table('devices')->orderBy('created_at')->get(['id', 'store_id', 'registration_status', 'is_active', 'code']) as $row) {
            $branchId = DB::table('stores')->where('id', $row->store_id)->value('branch_id');
            $status = $row->is_active ? (($row->registration_status ?? '') === 'registered' ? 'active' : 'pending') : 'revoked';

            DB::table('devices')->where('id', $row->id)->update([
                'code' => $row->code ?: 'DEVICE-'.str_pad((string) $sequence, 3, '0', STR_PAD_LEFT),
                'branch_id' => $branchId,
                'status' => $status,
            ]);
            $sequence++;
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('devices')) {
            return;
        }

        Schema::table('devices', function (Blueprint $table) {
            foreach (['user_id', 'branch_id'] as $column) {
                if (Schema::hasColumn('devices', $column)) {
                    $table->dropConstrainedForeignId($column);
                }
            }
            $drop = array_values(array_filter(
                ['code', 'local_server', 'status', 'revoked_at'],
                fn (string $column) => Schema::hasColumn('devices', $column),
            ));
            if ($drop !== []) {
                $table->dropColumn($drop);
            }
        });
    }
};
