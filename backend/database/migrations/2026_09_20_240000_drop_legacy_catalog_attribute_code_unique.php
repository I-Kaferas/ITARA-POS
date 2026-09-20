<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->dropUniqueIfColumns('catalog_attributes', ['tenant_id', 'code']);
        $this->dropUniqueIfColumns('brands', ['tenant_id', 'slug']);
        $this->ensureUnique('catalog_attributes', 'catalog_attributes_tenant_id_store_id_code_unique', ['tenant_id', 'store_id', 'code']);
        $this->ensureUnique('brands', 'brands_tenant_id_store_id_slug_unique', ['tenant_id', 'store_id', 'slug']);
    }

    public function down(): void
    {
        // Keep store-scoped uniqueness.
    }

    /**
     * @param  list<string>  $columns
     */
    private function dropUniqueIfColumns(string $table, array $columns): void
    {
        if (! Schema::hasTable($table)) {
            return;
        }

        foreach (Schema::getIndexes($table) as $index) {
            if (! ($index['unique'] ?? false) || ($index['primary'] ?? false)) {
                continue;
            }

            if (($index['columns'] ?? []) !== $columns) {
                continue;
            }

            Schema::table($table, function (Blueprint $blueprint) use ($index) {
                $blueprint->dropUnique($index['name']);
            });
        }
    }

    /**
     * @param  list<string>  $columns
     */
    private function ensureUnique(string $table, string $name, array $columns): void
    {
        if (! Schema::hasTable($table)) {
            return;
        }

        foreach (Schema::getIndexes($table) as $index) {
            if (($index['name'] ?? '') === $name) {
                return;
            }
        }

        Schema::table($table, function (Blueprint $blueprint) use ($columns) {
            $blueprint->unique($columns);
        });
    }
};
