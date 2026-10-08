<?php

namespace Tests\Feature\Platform;

use App\Models\Role;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Auth\AuthTokenService;
use App\Services\Rbac\RoleProvisioningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PlatformAdminTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_tenant_user_cannot_open_platform(): void
    {
        $fixture = $this->createTenantFixture('plat-deny', 'plat-deny@test.local');

        $this->getJson('/api/v1/platform/overview', $this->tenantHeaders($fixture['token'], $fixture['tenant']))
            ->assertForbidden();
    }

    public function test_super_admin_manages_every_tenant(): void
    {
        $this->seed(\Database\Seeders\PermissionSeeder::class);
        $role = app(RoleProvisioningService::class)->provisionSuperAdminRole();
        $admin = User::create([
            'tenant_id' => null,
            'name' => 'Platform',
            'email' => 'platform@test.local',
            'password' => Hash::make('password'),
            'is_active' => true,
        ]);
        $admin->roles()->attach($role->id, ['branch_id' => null, 'store_id' => null]);
        $token = app(AuthTokenService::class)->issue($admin)['access_token'];
        $headers = [
            'Authorization' => 'Bearer '.$token,
            'Accept' => 'application/json',
        ];

        $this->getJson('/api/v1/platform/overview', $headers)->assertOk();

        $this->postJson('/api/v1/platform/tenants', ['name' => 'Nouvelle enseigne'], $headers)
            ->assertCreated()
            ->assertJsonPath('data.tenant.name', 'Nouvelle enseigne')
            ->assertJsonPath('data.tenant.status', 'trial');

        $tenant = Tenant::query()->where('slug', 'nouvelle-enseigne')->firstOrFail();

        $this->patchJson('/api/v1/platform/companies/'.$tenant->id, [
            'plan' => 'pos_stock',
            'license_status' => 'suspended',
            'license_seats' => 4,
            'license_expires_on' => '2027-01-15',
            'subscription_status' => 'trial',
            'renews_on' => '2027-02-01',
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.subscription.plan', 'pos_stock')
            ->assertJsonPath('data.subscription.status', 'trial')
            ->assertJsonPath('data.license.status', 'suspended')
            ->assertJsonPath('data.license.seats', 4)
            ->assertJsonPath('data.modules', ['pos', 'inventory']);

        $this->patchJson('/api/v1/platform/companies/'.$tenant->id, [
            'modules' => ['pos', 'stock', 'hotel'],
            'status' => 'suspended',
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.modules', ['pos', 'inventory', 'hotel']);

        $tenant->refresh();
        $this->assertSame('suspended', $tenant->status);

        $this->postJson('/api/v1/platform/support', [
            'tenant_id' => $tenant->id,
            'subject' => 'Aide caisse',
            'message' => 'Le terminal ne se connecte plus.',
        ], $headers)->assertCreated();

        $ticketId = $this->getJson('/api/v1/platform/support', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.subject', 'Aide caisse')
            ->json('data.0.id');

        $this->postJson('/api/v1/platform/support/'.$ticketId.'/close', [], $headers)
            ->assertOk();

        $this->getJson('/api/v1/platform/companies', $headers)
            ->assertOk()
            ->assertJsonFragment(['id' => $tenant->id, 'status' => 'suspended']);

        $this->postJson('/api/v1/platform/tenants', [
            'name' => 'Boutique Nord',
            'slug' => 'boutique-nord',
            'plan' => 'pos_stock_restaurant',
            'admin_name' => 'Aline',
            'admin_email' => 'aline@boutique-nord.test',
            'admin_password' => 'secret-pass',
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.admin.email', 'aline@boutique-nord.test')
            ->assertJsonPath('data.tenant.status', 'trial');

        $this->postJson('/api/v1/platform/tenants', [
            'name' => 'Boutique Nord',
            'slug' => 'boutique-nord',
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.idempotent', true);

        $primary = User::withoutGlobalScopes()->where('email', 'aline@boutique-nord.test')->first();
        $this->assertNotNull($primary);
        $this->assertTrue(
            $primary->roles()->withoutGlobalScopes()->where('roles.slug', 'administrator')->exists()
        );

        $audit = $this->getJson('/api/v1/platform/audit', $headers)->assertOk()->json('data');
        $this->assertTrue(collect($audit)->contains(fn ($row) => $row['action'] === 'tenant.provisioned'));
        $this->assertFalse(collect($audit)->contains(fn ($row) => isset($row['payload']['admin_password']) || isset($row['payload']['password'])));

        $this->assertTrue(Role::query()->whereNull('tenant_id')->where('slug', 'super_admin')->exists());

        $this->getJson('/api/v1/auth/me', [
            'Authorization' => 'Bearer '.$token,
            'X-Tenant-ID' => $tenant->id,
            'Accept' => 'application/json',
        ])->assertOk()->assertJsonPath('user.is_super_admin', true);
    }
}
