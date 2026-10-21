<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->boolean('is_main')->default(false);
            $table->index(['tenant_id', 'is_main']);
        });

        $tenantIds = DB::table('stores')->whereNull('deleted_at')->distinct()->pluck('tenant_id');

        foreach ($tenantIds as $tenantId) {
            $hasMain = DB::table('stores')
                ->where('tenant_id', $tenantId)
                ->whereNull('deleted_at')
                ->where('is_main', true)
                ->exists();

            if ($hasMain) {
                continue;
            }

            $id = DB::table('stores')
                ->where('tenant_id', $tenantId)
                ->whereNull('deleted_at')
                ->orderBy('created_at')
                ->orderBy('id')
                ->value('id');

            if ($id) {
                DB::table('stores')->where('id', $id)->update(['is_main' => true]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'is_main']);
            $table->dropColumn('is_main');
        });
    }
};
