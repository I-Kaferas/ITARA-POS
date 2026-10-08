<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('cashier_shifts')) {
            return;
        }

        Schema::table('cashier_shifts', function (Blueprint $table) {
            if (! Schema::hasColumn('cashier_shifts', 'branch_id')) {
                $table->foreignUuid('branch_id')
                    ->nullable()
                    ->after('tenant_id')
                    ->constrained('branches')
                    ->nullOnDelete();
            }

            if (! Schema::hasColumn('cashier_shifts', 'device_id')) {
                $table->foreignUuid('device_id')
                    ->nullable()
                    ->after('cash_register_id')
                    ->constrained('devices')
                    ->nullOnDelete();
            }
        });

        $this->backfill();

        Schema::table('cashier_shifts', function (Blueprint $table) {
            $table->index(['tenant_id', 'branch_id', 'opened_at'], 'shifts_tenant_branch_opened_idx');
            $table->index(['tenant_id', 'device_id', 'status'], 'shifts_tenant_device_status_idx');
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('cashier_shifts')) {
            return;
        }

        Schema::table('cashier_shifts', function (Blueprint $table) {
            try {
                $table->dropIndex('shifts_tenant_branch_opened_idx');
            } catch (\Throwable) {
            }
            try {
                $table->dropIndex('shifts_tenant_device_status_idx');
            } catch (\Throwable) {
            }

            if (Schema::hasColumn('cashier_shifts', 'device_id')) {
                $table->dropConstrainedForeignId('device_id');
            }
            if (Schema::hasColumn('cashier_shifts', 'branch_id')) {
                $table->dropConstrainedForeignId('branch_id');
            }
        });
    }

    private function backfill(): void
    {
        if (! Schema::hasTable('cash_registers') || ! Schema::hasTable('stores')) {
            return;
        }

        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'sqlite') {
            $shifts = DB::table('cashier_shifts')
                ->whereNull('branch_id')
                ->orWhereNull('device_id')
                ->get(['id', 'cash_register_id', 'branch_id', 'device_id']);

            foreach ($shifts as $shift) {
                $register = DB::table('cash_registers')->where('id', $shift->cash_register_id)->first();
                if ($register === null) {
                    continue;
                }

                $branchId = $shift->branch_id;
                if ($branchId === null && Schema::hasColumn('stores', 'branch_id')) {
                    $branchId = DB::table('stores')->where('id', $register->store_id)->value('branch_id');
                }

                $deviceId = $shift->device_id ?? ($register->device_id ?? null);

                DB::table('cashier_shifts')->where('id', $shift->id)->update([
                    'branch_id' => $branchId,
                    'device_id' => $deviceId,
                ]);
            }

            return;
        }

        DB::statement('
            UPDATE cashier_shifts AS cs
            INNER JOIN cash_registers AS cr ON cr.id = cs.cash_register_id
            INNER JOIN stores AS s ON s.id = cr.store_id
            SET cs.branch_id = COALESCE(cs.branch_id, s.branch_id),
                cs.device_id = COALESCE(cs.device_id, cr.device_id)
            WHERE cs.branch_id IS NULL OR cs.device_id IS NULL
        ');
    }
};
