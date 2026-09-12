<?php

namespace Tests\Feature\Rbac;

use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class RoleManagementTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(\Database\Seeders\PermissionSeeder::class);
    }

    public function test_administrator_can_list_roles(): void
    {
        $fixture = $this->createTenantFixture('roles-list', 'roles-list@test.local');

        $response = $this->getJson('/api/v1/roles', $this->tenantHeaders($fixture['token'], $fixture['tenant']));

        $response->assertOk()
            ->assertJsonStructure(['data' => [['id', 'name', 'slug', 'permissions']]]);
    }

    public function test_administrator_can_assign_role_to_user(): void
    {
        $fixture = $this->createTenantFixture('roles-assign', 'roles-assign@test.local');

        $cashierRole = Role::query()
            ->where('tenant_id', $fixture['tenant']->id)
            ->where('slug', 'cashier')
            ->firstOrFail();

        $response = $this->postJson(
            '/api/v1/users/'.$fixture['user']->id.'/roles',
            ['role_id' => $cashierRole->id],
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
        );

        $response->assertCreated();
        $this->assertTrue($fixture['user']->fresh()->hasRole('cashier'));
    }

    public function test_cashier_cannot_manage_roles(): void
    {
        $fixture = $this->createTenantFixture('roles-deny', 'roles-deny@test.local');

        $cashierRole = Role::query()
            ->where('tenant_id', $fixture['tenant']->id)
            ->where('slug', 'cashier')
            ->firstOrFail();

        $fixture['user']->roles()->sync([
            $cashierRole->id => ['branch_id' => null, 'store_id' => null],
        ]);
        $fixture['user']->clearPermissionCache();

        $response = $this->getJson('/api/v1/roles', $this->tenantHeaders($fixture['token'], $fixture['tenant']));

        $response->assertForbidden();
    }

    public function test_administrator_can_list_permissions(): void
    {
        $fixture = $this->createTenantFixture('perms-list', 'perms-list@test.local');

        $response = $this->getJson('/api/v1/permissions', $this->tenantHeaders($fixture['token'], $fixture['tenant']));

        $response->assertOk()
            ->assertJsonStructure(['data' => [['group', 'permissions']]]);
    }
}
