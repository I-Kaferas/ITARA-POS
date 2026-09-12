<?php

namespace Tests\Feature\Tenancy;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class TenantApiIsolationTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_tenant_a_user_cannot_access_tenant_b_context(): void
    {
        $tenantA = $this->createTenantFixture('api-a', 'api-a@test.local');
        $tenantB = $this->createTenantFixture('api-b', 'api-b@test.local');

        $response = $this->getJson('/api/v1/companies', $this->tenantHeaders($tenantA['token'], $tenantB['tenant']));

        $response->assertForbidden();
    }

    public function test_tenant_a_user_only_sees_own_companies_via_api(): void
    {
        $tenantA = $this->createTenantFixture('api-a2', 'api-a2@test.local');
        $tenantB = $this->createTenantFixture('api-b2', 'api-b2@test.local');

        $response = $this->getJson('/api/v1/companies', $this->tenantHeaders($tenantA['token'], $tenantA['tenant']));

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.id', $tenantA['company']->id);
        $response->assertJsonMissing(['id' => $tenantB['company']->id]);
    }

    public function test_tenant_a_user_cannot_read_tenant_b_company_by_id(): void
    {
        $tenantA = $this->createTenantFixture('api-a3', 'api-a3@test.local');
        $tenantB = $this->createTenantFixture('api-b3', 'api-b3@test.local');

        $response = $this->getJson(
            '/api/v1/companies/'.$tenantB['company']->id,
            $this->tenantHeaders($tenantA['token'], $tenantA['tenant']),
        );

        $response->assertNotFound();
    }

    public function test_tenant_a_user_cannot_read_tenant_b_products(): void
    {
        $tenantA = $this->createTenantFixture('api-a4', 'api-a4@test.local');
        $tenantB = $this->createTenantFixture('api-b4', 'api-b4@test.local');

        $response = $this->getJson(
            '/api/v1/products/'.$tenantB['product']->id,
            $this->tenantHeaders($tenantA['token'], $tenantA['tenant']),
        );

        $response->assertNotFound();
    }

    public function test_api_requires_tenant_header(): void
    {
        $tenantA = $this->createTenantFixture('api-a5', 'api-a5@test.local');

        $response = $this->getJson('/api/v1/companies', [
            'Authorization' => 'Bearer '.$tenantA['token'],
            'Accept' => 'application/json',
        ]);

        $response->assertBadRequest();
    }
}
