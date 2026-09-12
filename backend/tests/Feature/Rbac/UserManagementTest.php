<?php

namespace Tests\Feature\Rbac;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class UserManagementTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(\Database\Seeders\PermissionSeeder::class);
    }

    public function test_administrator_can_crud_users(): void
    {
        $fixture = $this->createTenantFixture('users-crud', 'users-crud@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $created = $this->postJson('/api/v1/users', [
            'name' => 'Cashier One',
            'email' => 'cashier-one@test.local',
            'phone' => '68000000',
            'password' => 'password123',
            'is_active' => true,
        ], $headers)->assertCreated();

        $userId = $created->json('data.id');
        $this->assertNotEmpty($userId);

        $this->getJson('/api/v1/users', $headers)
            ->assertOk()
            ->assertJsonFragment(['email' => 'cashier-one@test.local']);

        $this->getJson("/api/v1/users/{$userId}", $headers)
            ->assertOk()
            ->assertJsonPath('data.email', 'cashier-one@test.local');

        $this->patchJson("/api/v1/users/{$userId}", [
            'name' => 'Cashier Updated',
            'is_active' => false,
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.name', 'Cashier Updated')
            ->assertJsonPath('data.is_active', false);

        $this->deleteJson("/api/v1/users/{$userId}", [], $headers)
            ->assertNoContent();

        $this->assertSoftDeleted('users', ['id' => $userId]);
    }

    public function test_user_cannot_delete_own_account(): void
    {
        $fixture = $this->createTenantFixture('users-self', 'users-self@test.local');

        $this->deleteJson(
            '/api/v1/users/'.$fixture['user']->id,
            [],
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
        )->assertStatus(422);
    }

    public function test_cashier_cannot_manage_users(): void
    {
        $fixture = $this->createTenantFixture('users-deny', 'users-deny@test.local');

        $cashierRole = \App\Models\Role::query()
            ->where('tenant_id', $fixture['tenant']->id)
            ->where('slug', 'cashier')
            ->firstOrFail();

        $fixture['user']->roles()->sync([
            $cashierRole->id => ['branch_id' => null, 'store_id' => null],
        ]);
        $fixture['user']->clearPermissionCache();

        $this->postJson('/api/v1/users', [
            'name' => 'Blocked',
            'email' => 'blocked@test.local',
            'password' => 'password123',
        ], $this->tenantHeaders($fixture['token'], $fixture['tenant']))->assertForbidden();
    }
}
