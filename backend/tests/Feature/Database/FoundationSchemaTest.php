<?php

namespace Tests\Feature\Database;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class FoundationSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_phase4_foundation_tables_exist(): void
    {
        $tables = [
            'tenants',
            'companies',
            'branches',
            'stores',
            'warehouses',
            'devices',
            'currencies',
            'users',
            'roles',
            'permissions',
            'role_permissions',
            'user_roles',
        ];

        foreach ($tables as $table) {
            $this->assertTrue(Schema::hasTable($table), "Missing table: {$table}");
        }
    }

    public function test_users_table_uses_uuid_primary_key(): void
    {
        $this->assertTrue(Schema::hasColumn('users', 'id'));
        $this->assertTrue(Schema::hasColumn('users', 'tenant_id'));
        $this->assertTrue(Schema::hasColumn('users', 'phone'));
        $this->assertTrue(Schema::hasColumn('users', 'is_active'));
        $this->assertTrue(Schema::hasColumn('users', 'deleted_at'));
    }
}
