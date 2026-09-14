<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'pin')) {
            return;
        }

        $this->assignMissingPins();
        $this->resolveDuplicatePins();

        Schema::table('users', function (Blueprint $table) {
            $table->unique(['tenant_id', 'pin'], 'users_tenant_pin_unique');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique('users_tenant_pin_unique');
        });
    }

    private function assignMissingPins(): void
    {
        $missing = DB::table('users')
            ->where(function ($query) {
                $query->whereNull('pin')->orWhere('pin', '');
            })
            ->get(['id', 'tenant_id']);

        foreach ($missing as $user) {
            DB::table('users')->where('id', $user->id)->update([
                'pin' => $this->freshPin($user->tenant_id),
            ]);
        }
    }

    private function resolveDuplicatePins(): void
    {
        $rows = DB::table('users')
            ->whereNotNull('pin')
            ->where('pin', '!=', '')
            ->orderBy('created_at')
            ->get(['id', 'tenant_id', 'pin']);

        $seen = [];
        foreach ($rows as $row) {
            $key = ($row->tenant_id ?? '').'|'.$row->pin;
            if (isset($seen[$key])) {
                DB::table('users')->where('id', $row->id)->update([
                    'pin' => $this->freshPin($row->tenant_id),
                ]);
                continue;
            }
            $seen[$key] = true;
        }
    }

    private function freshPin(?string $tenantId): string
    {
        for ($attempt = 0; $attempt < 80; $attempt++) {
            $pin = str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT);
            $exists = DB::table('users')
                ->when($tenantId, fn ($query) => $query->where('tenant_id', $tenantId))
                ->where('pin', $pin)
                ->exists();

            if (! $exists) {
                return $pin;
            }
        }

        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }
};
