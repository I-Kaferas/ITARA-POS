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

        $this->ensureIndex('shifts_tenant_branch_opened_idx', ['tenant_id', 'branch_id', 'opened_at']);
        $this->ensureIndex('shifts_tenant_device_status_idx', ['tenant_id', 'device_id', 'status']);
    }

    public function down(): void
    {
        if (! Schema::hasTable('cashier_shifts')) {
            return;
        }

        Schema::table('cashier_shifts', function (Blueprint $table) {
            foreach (['shifts_tenant_branch_opened_idx', 'shifts_tenant_device_status_idx'] as $index) {
                if ($this->hasIndex($index)) {
                    $table->dropIndex($index);
                }
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

        $shifts = DB::table('cashier_shifts')
            ->where(function ($query) {
                $query->whereNull('branch_id')->orWhereNull('device_id');
            })
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
    }

    /**
     * @param  list<string>  $columns
     */
    private function ensureIndex(string $name, array $columns): void
    {
        if ($this->hasIndex($name)) {
            return;
        }

        Schema::table('cashier_shifts', function (Blueprint $table) use ($name, $columns) {
            $table->index($columns, $name);
        });
    }

    private function hasIndex(string $name): bool
    {
        return collect(Schema::getIndexes('cashier_shifts'))
            ->contains(fn (array $index): bool => ($index['name'] ?? '') === $name);
    }
};
