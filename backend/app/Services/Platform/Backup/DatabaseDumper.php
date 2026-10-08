<?php

namespace App\Services\Platform\Backup;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Process;
use RuntimeException;
use Throwable;

class DatabaseDumper
{
    /**
     * @return array{driver: string, tables: int, rows: int, method: string}
     */
    public function dump(string $absolutePath): array
    {
        $connection = DB::connection();
        $driver = $connection->getDriverName();

        if ($driver === 'pgsql' && $this->tryPgDump($absolutePath)) {
            return [
                'driver' => $driver,
                'tables' => 0,
                'rows' => 0,
                'method' => 'pg_dump',
            ];
        }

        if (in_array($driver, ['mysql', 'mariadb'], true) && $this->tryMysqlDump($absolutePath)) {
            return [
                'driver' => $driver,
                'tables' => 0,
                'rows' => 0,
                'method' => 'mysqldump',
            ];
        }

        return $this->dumpLogical($absolutePath, $driver);
    }

    /**
     * @return array{driver: string, tables: int, rows: int, method: string}
     */
    private function dumpLogical(string $absolutePath, string $driver): array
    {
        $connection = DB::connection();
        $tables = $this->listTables($driver);
        $handle = fopen($absolutePath, 'wb');
        if ($handle === false) {
            throw new RuntimeException('Unable to open backup dump file.');
        }

        $rows = 0;
        try {
            fwrite($handle, "-- ITARA-POS logical database backup\n");
            fwrite($handle, '-- driver: '.$driver."\n");
            fwrite($handle, '-- created: '.now()->toIso8601String()."\n\n");
            fwrite($handle, "PRAGMA foreign_keys=OFF;\n");
            fwrite($handle, "BEGIN;\n\n");

            foreach ($tables as $table) {
                if ($driver === 'sqlite') {
                    $create = $connection->selectOne(
                        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
                        [$table]
                    );
                    if (is_object($create) && ! empty($create->sql)) {
                        fwrite($handle, 'DROP TABLE IF EXISTS '.$this->quoteIdent($table, $driver).";\n");
                        fwrite($handle, $create->sql.";\n\n");
                    }
                } else {
                    fwrite($handle, 'DELETE FROM '.$this->quoteIdent($table, $driver).";\n");
                }

                $connection->table($table)->orderBy($this->firstColumn($table))->chunk(200, function ($chunk) use ($handle, $table, $driver, &$rows): void {
                    foreach ($chunk as $row) {
                        $data = (array) $row;
                        $columns = array_map(fn ($c) => $this->quoteIdent((string) $c, $driver), array_keys($data));
                        $values = array_map(fn ($v) => $this->quoteValue($v), array_values($data));
                        fwrite(
                            $handle,
                            'INSERT INTO '.$this->quoteIdent($table, $driver).' ('.implode(', ', $columns).') VALUES ('.implode(', ', $values).");\n"
                        );
                        $rows++;
                    }
                });
                fwrite($handle, "\n");
            }

            fwrite($handle, "COMMIT;\n");
            fwrite($handle, "PRAGMA foreign_keys=ON;\n");
        } finally {
            fclose($handle);
        }

        return [
            'driver' => $driver,
            'tables' => count($tables),
            'rows' => $rows,
            'method' => 'logical',
        ];
    }

    public function restore(string $absolutePath): void
    {
        if (! is_file($absolutePath)) {
            throw new RuntimeException('Database dump not found.');
        }

        $sql = file_get_contents($absolutePath);
        if ($sql === false || trim($sql) === '') {
            throw new RuntimeException('Database dump is empty.');
        }

        $connection = DB::connection();
        $driver = $connection->getDriverName();

        if ($driver === 'pgsql' && str_contains($sql, 'PostgreSQL database dump')) {
            if ($this->tryPsql($absolutePath)) {
                return;
            }
        }

        if (in_array($driver, ['mysql', 'mariadb'], true) && $this->tryMysql($absolutePath)) {
            return;
        }

        // Strip SQLite-only pragmas for other drivers.
        if ($driver !== 'sqlite') {
            $sql = preg_replace('/^PRAGMA .+$/mi', '', $sql) ?? $sql;
        }

        $connection->unprepared($sql);
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
            if ($name === '' || str_starts_with($name, 'platform_backup')) {
                continue;
            }
            $tables[] = $name;
        }

        return $tables;
    }

    private function firstColumn(string $table): string
    {
        $columns = DB::getSchemaBuilder()->getColumnListing($table);

        return $columns[0] ?? 'id';
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

    private function tryPgDump(string $absolutePath): bool
    {
        $cfg = config('database.connections.pgsql', []);
        $bin = env('BACKUP_PG_DUMP', 'pg_dump');
        $env = [
            'PGPASSWORD' => (string) ($cfg['password'] ?? ''),
        ];

        try {
            $result = Process::env($env)->run([
                $bin,
                '-h', (string) ($cfg['host'] ?? '127.0.0.1'),
                '-p', (string) ($cfg['port'] ?? 5432),
                '-U', (string) ($cfg['username'] ?? 'postgres'),
                '-d', (string) ($cfg['database'] ?? 'pos'),
                '-F', 'p',
                '--no-owner',
                '--no-acl',
                '-f', $absolutePath,
            ]);

            return $result->successful() && is_file($absolutePath) && filesize($absolutePath) > 0;
        } catch (Throwable) {
            return false;
        }
    }

    private function tryMysqlDump(string $absolutePath): bool
    {
        $driver = DB::connection()->getDriverName();
        $cfg = config('database.connections.'.$driver, []);
        $bin = env('BACKUP_MYSQLDUMP', 'mysqldump');

        try {
            $result = Process::run([
                $bin,
                '-h', (string) ($cfg['host'] ?? '127.0.0.1'),
                '-P', (string) ($cfg['port'] ?? 3306),
                '-u', (string) ($cfg['username'] ?? 'root'),
                '-p'.(string) ($cfg['password'] ?? ''),
                '--single-transaction',
                '--routines',
                '--triggers',
                (string) ($cfg['database'] ?? ''),
                '--result-file='.$absolutePath,
            ]);

            return $result->successful() && is_file($absolutePath) && filesize($absolutePath) > 0;
        } catch (Throwable) {
            return false;
        }
    }

    private function tryPsql(string $absolutePath): bool
    {
        $cfg = config('database.connections.pgsql', []);
        $bin = env('BACKUP_PSQL', 'psql');
        $env = ['PGPASSWORD' => (string) ($cfg['password'] ?? '')];

        try {
            $result = Process::env($env)->run([
                $bin,
                '-h', (string) ($cfg['host'] ?? '127.0.0.1'),
                '-p', (string) ($cfg['port'] ?? 5432),
                '-U', (string) ($cfg['username'] ?? 'postgres'),
                '-d', (string) ($cfg['database'] ?? 'pos'),
                '-f', $absolutePath,
            ]);

            return $result->successful();
        } catch (Throwable) {
            return false;
        }
    }

    private function tryMysql(string $absolutePath): bool
    {
        $driver = DB::connection()->getDriverName();
        $cfg = config('database.connections.'.$driver, []);
        $bin = env('BACKUP_MYSQL', 'mysql');

        try {
            $result = Process::input((string) file_get_contents($absolutePath))->run([
                $bin,
                '-h', (string) ($cfg['host'] ?? '127.0.0.1'),
                '-P', (string) ($cfg['port'] ?? 3306),
                '-u', (string) ($cfg['username'] ?? 'root'),
                '-p'.(string) ($cfg['password'] ?? ''),
                (string) ($cfg['database'] ?? ''),
            ]);

            return $result->successful();
        } catch (Throwable) {
            return false;
        }
    }
}
