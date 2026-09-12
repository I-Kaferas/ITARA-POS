<?php

namespace Tests\Feature\Rbac;

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class RbacEnforcementTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(\Database\Seeders\PermissionSeeder::class);
    }

    public function test_administrator_can_access_protected_routes(): void
    {
        $fixture = $this->createTenantFixture('rbac-admin', 'rbac-admin@test.local');

        $response = $this->getJson('/api/v1/companies', $this->tenantHeaders($fixture['token'], $fixture['tenant']));

        $response->assertOk();
    }

    public function test_user_without_permissions_gets_forbidden(): void
    {
        $fixture = $this->createTenantFixture('rbac-deny', 'rbac-deny@test.local');

        $fixture['user']->roles()->detach();
        $fixture['user']->clearPermissionCache();

        $response = $this->getJson('/api/v1/companies', $this->tenantHeaders($fixture['token'], $fixture['tenant']));

        $response->assertForbidden()
            ->assertJsonPath('message', 'Forbidden. Insufficient permissions.');
    }

    public function test_cashier_can_view_products_but_not_manage_companies(): void
    {
        $fixture = $this->createTenantFixture('rbac-cashier', 'rbac-cashier@test.local');

        $cashierRole = Role::query()
            ->where('tenant_id', $fixture['tenant']->id)
            ->where('slug', 'cashier')
            ->firstOrFail();

        $fixture['user']->roles()->sync([
            $cashierRole->id => ['branch_id' => null, 'store_id' => null],
        ]);
        $fixture['user']->clearPermissionCache();

        $this->getJson(
            '/api/v1/catalogs/'.$fixture['catalog']->id.'/products',
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
        )->assertOk();

        $this->getJson(
            '/api/v1/companies',
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
        )->assertForbidden();
    }

    public function test_login_returns_permissions_in_user_payload(): void
    {
        $fixture = $this->createTenantFixture('rbac-login', 'rbac-login@test.local');

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'rbac-login@test.local',
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'user' => ['roles', 'permissions', 'role_assignments'],
            ]);

        $permissions = $response->json('user.permissions');
        $this->assertContains('organization.companies.view', $permissions);
        $this->assertContains('catalog.products.manage', $permissions);
    }

    public function test_all_ten_system_roles_are_provisioned_for_tenant(): void
    {
        $fixture = $this->createTenantFixture('rbac-roles', 'rbac-roles@test.local');

        $expectedSlugs = [
            'company_owner',
            'administrator',
            'branch_manager',
            'store_manager',
            'cashier',
            'inventory_manager',
            'accountant',
            'sales_agent',
            'auditor',
        ];

        foreach ($expectedSlugs as $slug) {
            $this->assertTrue(
                Role::query()->where('tenant_id', $fixture['tenant']->id)->where('slug', $slug)->exists(),
                "Missing role: {$slug}",
            );
        }
    }

    public function test_super_admin_bypasses_all_permission_checks(): void
    {
        $this->seed(\Database\Seeders\RoleSeeder::class);

        $superAdminRole = Role::query()->where('slug', 'super_admin')->firstOrFail();

        $superAdmin = User::create([
            'tenant_id' => null,
            'name' => 'Super Admin',
            'email' => 'super@test.local',
            'password' => bcrypt('password'),
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        $superAdmin->roles()->attach($superAdminRole->id, [
            'branch_id' => null,
            'store_id' => null,
        ]);

        $this->assertTrue($superAdmin->isSuperAdmin());
        $this->assertTrue($superAdmin->hasPermission('organization.companies.manage'));
        $this->assertTrue($superAdmin->hasPermission('audit.view'));
    }
}
