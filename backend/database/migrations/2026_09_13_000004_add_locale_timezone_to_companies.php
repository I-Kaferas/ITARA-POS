<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('companies')) {
            return;
        }

        Schema::table('companies', function (Blueprint $table) {
            if (! Schema::hasColumn('companies', 'locale')) {
                $table->string('locale', 20)->default('fr');
            }
            if (! Schema::hasColumn('companies', 'timezone')) {
                $table->string('timezone', 64)->default('Africa/Bujumbura');
            }
        });

        foreach (DB::table('companies')->select('id', 'settings', 'locale', 'timezone')->get() as $row) {
            $settings = json_decode((string) ($row->settings ?? ''), true);
            $settings = is_array($settings) ? $settings : [];

            DB::table('companies')->where('id', $row->id)->update([
                'locale' => is_string($settings['locale'] ?? null) && $settings['locale'] !== ''
                    ? $settings['locale']
                    : ($row->locale ?: 'fr'),
                'timezone' => is_string($settings['timezone'] ?? null) && $settings['timezone'] !== ''
                    ? $settings['timezone']
                    : ($row->timezone ?: 'Africa/Bujumbura'),
            ]);
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('companies')) {
            return;
        }

        Schema::table('companies', function (Blueprint $table) {
            if (Schema::hasColumn('companies', 'locale')) {
                $table->dropColumn('locale');
            }
            if (Schema::hasColumn('companies', 'timezone')) {
                $table->dropColumn('timezone');
            }
        });
    }
};
