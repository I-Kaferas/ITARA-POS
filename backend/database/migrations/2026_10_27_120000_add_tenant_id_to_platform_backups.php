<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('platform_backups', function (Blueprint $table) {
            $table->foreignUuid('tenant_id')->nullable()->after('type')->constrained('tenants')->nullOnDelete();
            $table->index(['tenant_id', 'finished_at']);
        });
    }

    public function down(): void
    {
        Schema::table('platform_backups', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'finished_at']);
            $table->dropConstrainedForeignId('tenant_id');
        });
    }
};
