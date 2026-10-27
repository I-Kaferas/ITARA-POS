<?php

namespace App\Services\Platform\Backup;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Exports and restores one company's rows from the shared database.
 * Tables are selected by a tenant_id column. Role and warehouse links
 * that have no tenant_id are included through their parent ids.
 */
class TenantDatabaseDumper
{
    /** @var list<string> */
    private const SKIP = [
        'platform_backups',
        'platform_backup_restores',
        'platform_backup_settings',
        'migrations',
        'jobs',
        'job_batches',
        'failed_jobs',
        'cache',
        'cache_locks',
        'sessions',
    ];

    /**
     * @return array{driver: string, tables: int, rows: int, method: string, tenant_id: string}
     */
    public function dump(string $absolutePath, string $tenantId): array
    {
        $this->assertUuid($tenantId);
        $driver = DB::connection()->getDriverName();
        $handle = fopen($absolutePath, 'wb');
        if ($handle === false) {
            throw new RuntimeException('Unable to open company backup file.');
        }

        $rows = 0;
        $tables = 0;

        try {
            fwrite($handle, "-- ITARA-POS tenant backup\n");
            fwrite($handle, '-- tenant_id: '.$tenantId."\n");
            fwrite($handle, '-- driver: '.$driver."\n");
            fwrite($handle, '-- created: '.now()->toIso8601String()."\n");
            fwrite($handle, "-- scope: tenant\n\n");
            fwrite($handle, $this->foreignKeysOff($driver));
            fwrite($handle, "BEGIN;\n\n");

            $userIds = Schema::hasTable('users')
                ? DB::table('users')->where('tenant_id', $tenantId)->pluck('id')->map(fn ($id) => (string) $id)->all()
                : [];
            $deviceIds = Schema::hasTable('devices')
                ? DB::table('devices')->where('tenant_id', $tenantId)->pluck('id')->map(fn ($id) => (string) $id)->all()
                : [];
            $ordered = $this->parentsFirst($this->tenantTables($driver), $driver);
            $tables = count($ordered);

            $rows += $this->writePivotDelete($handle, 'user_roles', 'user_id', $userIds, $driver);
            $rows += $this->writePivotDelete($handle, 'device_warehouse', 'device_id', $deviceIds, $driver);

            foreach (array_reverse($ordered) as $table) {
                fwrite($handle, 'DELETE FROM '.$this->quoteIdent($table, $driver).' WHERE '.$this->quoteIdent('tenant_id', $driver).' = '.$this->quoteValue($tenantId).";\n");
            }
            if (Schema::hasTable('tenants')) {
                fwrite($handle, 'DELETE FROM '.$this->quoteIdent('tenants', $driver).' WHERE '.$this->quoteIdent('id', $driver).' = '.$this->quoteValue($tenantId).";\n");
            }
            fwrite($handle, "\n");

            if (Schema::hasTable('tenants')) {
                $tenant = DB::table('tenants')->where('id', $tenantId)->first();
                if ($tenant) {
                    $this->writeInsert($handle, 'tenants', (array) $tenant, $driver);
                    $rows++;
                }
            }
            foreach ($ordered as $table) {
                DB::table($table)->where('tenant_id', $tenantId)->orderBy($this->firstColumn($table))->chunk(200, function ($chunk) use ($handle, $table, $driver, &$rows): void {
                    foreach ($chunk as $row) {
                        $this->writeInsert($handle, $table, (array) $row, $driver);
                        $rows++;
                    }
                });
            }

            $rows += $this->writePivotInsert($handle, 'user_roles', 'user_id', $userIds, $driver);
            $rows += $this->writePivotInsert($handle, 'device_warehouse', 'device_id', $deviceIds, $driver);

            fwrite($handle, "COMMIT;\n");
            fwrite($handle, $this->foreignKeysOn($driver));
        } finally {
            fclose($handle);
        }

        return [
            'driver' => $driver,
            'tables' => $tables,
            'rows' => $rows,
            'method' => 'tenant',
            'tenant_id' => $tenantId,
        ];
    }

    public function restore(string $absolutePath, string $tenantId): void
    {
        $this->assertUuid($tenantId);
        if (! is_file($absolutePath)) {
            throw new RuntimeException('Company database dump not found.');
        }

        $sql = file_get_contents($absolutePath);
        if ($sql === false || trim($sql) === '') {
            throw new RuntimeException('Company database dump is empty.');
        }
        if (! str_contains($sql, '-- tenant_id: '.$tenantId)) {
            throw new RuntimeException('This dump belongs to another company.');
        }
        if (! str_contains($sql, '-- scope: tenant')) {
            throw new RuntimeException('This dump is not a company backup.');
        }

        $driver = DB::connection()->getDriverName();
        if ($driver !== 'sqlite') {
            $sql = preg_replace('/^PRAGMA .+$/mi', '', $sql) ?? $sql;
        }

        $this->executeScript($sql);
    }

    private function executeScript(string $sql): void
    {
        $buffer = '';
        $inString = false;
        $length = strlen($sql);
        for ($i = 0; $i < $length; $i++) {
            $char = $sql[$i];
            if ($char === "'") {
                if ($inString && ($sql[$i + 1] ?? '') === "'") {
                    $buffer .= "''";
                    $i++;

                    continue;
                }
                $inString = ! $inString;
            }
            if ($char === ';' && ! $inString) {
                $this->runStatement($buffer);
                $buffer = '';

                continue;
            }
            $buffer .= $char;
        }
        $this->runStatement($buffer);
    }

    private function runStatement(string $statement): void
    {
        $statement = trim($statement);
        if ($statement === '') {
            return;
        }
        $withoutComments = trim((string) preg_replace('/^--.*$/m', '', $statement));
        if ($withoutComments === '') {
            return;
        }
        $command = strtoupper($withoutComments);
        if (DB::transactionLevel() > 0 && (
            in_array($command, ['BEGIN', 'COMMIT', 'ROLLBACK'], true)
            || str_starts_with($command, 'PRAGMA FOREIGN_KEYS')
        )) {
            return;
        }
        DB::unprepared($statement);
    }

    /** @return list<string> */
    private function tenantTables(string $driver): array
    {
        $names = [];
        foreach ($this->listTables($driver) as $table) {
            if (in_array($table, self::SKIP, true) || $table === 'tenants') {
                continue;
            }
            if (! Schema::hasColumn($table, 'tenant_id')) {
                continue;
            }
            $names[] = $table;
        }

        return $names;
    }

    /** @return list<string> */
    private function listTables(string $driver): array
    {
        $connection = DB::connection();
        if ($driver === 'sqlite') {
            $rows = $connection->select("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
        } elseif ($driver === 'pgsql') {
            $rows = $connection->select("SELECT tablename AS name FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename");
        } else {
            $database = $connection->getDatabaseName();
            $rows = $connection->select(
                'SELECT table_name AS name FROM information_schema.tables WHERE table_schema = ? AND table_type = ? ORDER BY table_name',
                [$database ?: 'public', 'BASE TABLE']
            );
        }

        $tables = [];
        foreach ($rows as $row) {
            $name = (string) ($row->name ?? '');
            if ($name !== '') {
                $tables[] = $name;
            }
        }

        return $tables;
    }

    /**
     * @param  list<string>  $tables
     * @return list<string>
     */
    private function parentsFirst(array $tables, string $driver): array
    {
        $set = array_fill_keys($tables, true);
        $deps = [];
        foreach ($tables as $table) {
            $deps[$table] = [];
            foreach ($this->foreignTables($table, $driver) as $parent) {
                if ($parent !== $table && isset($set[$parent])) {
                    $deps[$table][$parent] = true;
                }
            }
        }

        $ordered = [];
        $remaining = $set;
        while ($remaining !== []) {
            $ready = null;
            foreach (array_keys($remaining) as $table) {
                $pending = array_intersect_key($deps[$table], $remaining);
                if ($pending === []) {
                    $ready = $table;
                    break;
                }
            }
            if ($ready === null) {
                $ordered = array_merge($ordered, array_keys($remaining));
                break;
            }
            $ordered[] = $ready;
            unset($remaining[$ready]);
        }

        return $ordered;
    }

    /** @return list<string> */
    private function foreignTables(string $table, string $driver): array
    {
        if ($driver === 'sqlite') {
            $rows = DB::select('PRAGMA foreign_key_list('.$this->quoteIdent($table, $driver).')');

            return array_values(array_unique(array_map(
                fn ($row) => (string) ($row->table ?? ''),
                $rows
            )));
        }

        if ($driver === 'pgsql') {
            $rows = DB::select(
                'SELECT ccu.table_name AS parent
                 FROM information_schema.table_constraints tc
                 JOIN information_schema.constraint_column_usage ccu
                   ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
                 WHERE tc.constraint_type = ? AND tc.table_schema = ? AND tc.table_name = ?',
                ['FOREIGN KEY', 'public', $table]
            );
        } else {
            $rows = DB::select(
                'SELECT referenced_table_name AS parent
                 FROM information_schema.key_column_usage
                 WHERE table_schema = ? AND table_name = ? AND referenced_table_name IS NOT NULL',
                [DB::connection()->getDatabaseName() ?: 'public', $table]
            );
        }

        return array_values(array_unique(array_map(fn ($row) => (string) ($row->parent ?? ''), $rows)));
    }

    /** @param  list<string>  $ids */
    private function writePivotDelete($handle, string $table, string $column, array $ids, string $driver): int
    {
        if ($ids === [] || ! Schema::hasTable($table)) {
            return 0;
        }

        $quoted = implode(', ', array_map(fn (string $id) => $this->quoteValue($id), $ids));
        fwrite($handle, 'DELETE FROM '.$this->quoteIdent($table, $driver).' WHERE '.$this->quoteIdent($column, $driver).' IN ('.$quoted.");\n");

        return 0;
    }

    /** @param  list<string>  $ids */
    private function writePivotInsert($handle, string $table, string $column, array $ids, string $driver): int
    {
        if ($ids === [] || ! Schema::hasTable($table)) {
            return 0;
        }

        $rows = 0;
        foreach (array_chunk($ids, 200) as $chunkIds) {
            foreach (DB::table($table)->whereIn($column, $chunkIds)->get() as $row) {
                $this->writeInsert($handle, $table, (array) $row, $driver);
                $rows++;
            }
        }

        return $rows;
    }

    /** @param  array<string, mixed>  $data */
    private function writeInsert($handle, string $table, array $data, string $driver): void
    {
        $columns = array_map(fn ($column) => $this->quoteIdent((string) $column, $driver), array_keys($data));
        $values = array_map(fn ($value) => $this->quoteValue($value), array_values($data));
        fwrite(
            $handle,
            'INSERT INTO '.$this->quoteIdent($table, $driver).' ('.implode(', ', $columns).') VALUES ('.implode(', ', $values).");\n"
        );
    }

    private function firstColumn(string $table): string
    {
        $columns = Schema::getColumnListing($table);

        return $columns[0] ?? 'id';
    }

    private function foreignKeysOff(string $driver): string
    {
        return match ($driver) {
            'sqlite' => "PRAGMA foreign_keys=OFF;\n",
            'pgsql' => "SET session_replication_role = replica;\n",
            default => "SET FOREIGN_KEY_CHECKS=0;\n",
        };
    }

    private function foreignKeysOn(string $driver): string
    {
        return match ($driver) {
            'sqlite' => "PRAGMA foreign_keys=ON;\n",
            'pgsql' => "SET session_replication_role = origin;\n",
            default => "SET FOREIGN_KEY_CHECKS=1;\n",
        };
    }

    private function assertUuid(string $tenantId): void
    {
        if (! Str::isUuid($tenantId)) {
            throw new RuntimeException('Company id is not a valid identifier.');
        }
    }

    private function quoteIdent(string $ident, string $driver): string
    {
        if ($driver === 'mysql' || $driver === 'mariadb') {
            return '`'.str_replace('`', '``', $ident).'`';
        }

        return '"'.str_replace('"', '""', $ident).'"';
    }

    private function quoteValue(mixed $value): string
    {
        if ($value === null) {
            return 'NULL';
        }
        if (is_bool($value)) {
            return $value ? '1' : '0';
        }
        if (is_int($value) || is_float($value)) {
            return (string) $value;
        }

        return DB::getPdo()->quote((string) $value);
    }
}
