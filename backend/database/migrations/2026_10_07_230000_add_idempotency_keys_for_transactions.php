<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('transactions') && ! Schema::hasColumn('transactions', 'idempotency_key')) {
            Schema::table('transactions', function (Blueprint $table) {
                $table->string('idempotency_key', 100)->nullable()->after('reference');
            });
        }

        $this->dedupeNullableKeys('sales', 'idempotency_key');
        $this->dedupeNullableKeys('payment_transactions', 'idempotency_key');
        $this->dedupeNullableKeys('transactions', 'idempotency_key');

        if (Schema::hasTable('payment_transactions')
            && Schema::hasIndex('payment_transactions', 'payment_transactions_tenant_id_idempotency_key_index')) {
            Schema::table('payment_transactions', function (Blueprint $table) {
                $table->dropIndex('payment_transactions_tenant_id_idempotency_key_index');
            });
        }

        $this->uniqueIfMissing('sales', ['tenant_id', 'idempotency_key'], 'sales_tenant_idempotency_unique');
        $this->uniqueIfMissing('payment_transactions', ['tenant_id', 'idempotency_key'], 'payment_tx_tenant_idempotency_unique');
        $this->uniqueIfMissing('transactions', ['tenant_id', 'idempotency_key'], 'transactions_tenant_idempotency_unique');
    }

    public function down(): void
    {
        $this->dropUniqueIfExists('sales', 'sales_tenant_idempotency_unique');
        $this->dropUniqueIfExists('payment_transactions', 'payment_tx_tenant_idempotency_unique');
        $this->dropUniqueIfExists('transactions', 'transactions_tenant_idempotency_unique');

        if (Schema::hasTable('payment_transactions')
            && ! Schema::hasIndex('payment_transactions', 'payment_transactions_tenant_id_idempotency_key_index')) {
            Schema::table('payment_transactions', function (Blueprint $table) {
                $table->index(['tenant_id', 'idempotency_key']);
            });
        }

        if (Schema::hasTable('transactions') && Schema::hasColumn('transactions', 'idempotency_key')) {
            Schema::table('transactions', function (Blueprint $table) {
                $table->dropColumn('idempotency_key');
            });
        }
    }

    private function dedupeNullableKeys(string $table, string $column): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasColumn($table, $column)) {
            return;
        }

        $duplicates = DB::table($table)
            ->select('tenant_id', $column)
            ->whereNotNull($column)
            ->groupBy('tenant_id', $column)
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($duplicates as $duplicate) {
            $ids = DB::table($table)
                ->where('tenant_id', $duplicate->tenant_id)
                ->where($column, $duplicate->{$column})
                ->orderBy('created_at')
                ->pluck('id');

            $ids->slice(1)->each(function ($id) use ($table, $column): void {
                DB::table($table)->where('id', $id)->update([$column => null]);
            });
        }
    }

    /** @param  list<string>  $columns */
    private function uniqueIfMissing(string $table, array $columns, string $indexName): void
    {
        if (! Schema::hasTable($table) || Schema::hasIndex($table, $indexName)) {
            return;
        }

        foreach ($columns as $column) {
            if (! Schema::hasColumn($table, $column)) {
                return;
            }
        }

        Schema::table($table, function (Blueprint $blueprint) use ($columns, $indexName): void {
            $blueprint->unique($columns, $indexName);
        });
    }

    private function dropUniqueIfExists(string $table, string $indexName): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasIndex($table, $indexName)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($indexName): void {
            $blueprint->dropUnique($indexName);
        });
    }
};
