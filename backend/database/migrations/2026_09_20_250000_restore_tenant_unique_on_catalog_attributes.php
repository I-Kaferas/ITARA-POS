<?php

use Illuminate\Database\Migrations\Migration;

/**
 * Previously restored a tenant-wide unique on catalog_attributes.code.
 * That blocked per-store attributes; uniqueness is store-scoped instead.
 */
return new class extends Migration
{
    public function up(): void
    {
        //
    }

    public function down(): void
    {
        //
    }
};
