<?php

namespace Tests\Feature\Tenancy;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Supplier;
use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class TenantIsolationTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_tenant_a_cannot_read_tenant_b_companies(): void
    {
        $tenantA = $this->createTenantFixture('tenant-a', 'a@test.local');
        $tenantB = $this->createTenantFixture('tenant-b', 'b@test.local');

        app(TenantContext::class)->bind($tenantA['tenant']);

        $this->assertCount(1, Company::all());
        $this->assertTrue(Company::query()->whereKey($tenantA['company']->id)->exists());
        $this->assertFalse(Company::query()->whereKey($tenantB['company']->id)->exists());
    }

    public function test_tenant_a_cannot_find_tenant_b_product_by_id(): void
    {
        $tenantA = $this->createTenantFixture('tenant-a2', 'a2@test.local');
        $tenantB = $this->createTenantFixture('tenant-b2', 'b2@test.local');

        app(TenantContext::class)->bind($tenantA['tenant']);

        $this->assertNull(Product::query()->find($tenantB['product']->id));
        $this->assertNotNull(Product::query()->find($tenantA['product']->id));
    }

    public function test_tenant_a_cannot_read_tenant_b_customers_or_suppliers(): void
    {
        $tenantA = $this->createTenantFixture('tenant-a3', 'a3@test.local');
        $tenantB = $this->createTenantFixture('tenant-b3', 'b3@test.local');

        app(TenantContext::class)->bind($tenantA['tenant']);

        $this->assertCount(1, Customer::all());
        $this->assertCount(1, Supplier::all());
        $this->assertFalse(Customer::query()->whereKey($tenantB['customer']->id)->exists());
        $this->assertFalse(Supplier::query()->whereKey($tenantB['supplier']->id)->exists());
    }

    public function test_new_records_are_auto_assigned_to_current_tenant(): void
    {
        $tenantA = $this->createTenantFixture('tenant-a4', 'a4@test.local');

        app(TenantContext::class)->bind($tenantA['tenant']);

        $customer = Customer::create([
            'name' => 'Auto scoped',
            'is_active' => true,
        ]);

        $this->assertSame($tenantA['tenant']->id, $customer->tenant_id);
    }

    public function test_cannot_create_record_for_another_tenant(): void
    {
        $tenantA = $this->createTenantFixture('tenant-a5', 'a5@test.local');
        $tenantB = $this->createTenantFixture('tenant-b5', 'b5@test.local');

        app(TenantContext::class)->bind($tenantA['tenant']);

        $this->expectException(ValidationException::class);

        Customer::create([
            'tenant_id' => $tenantB['tenant']->id,
            'name' => 'Cross tenant',
            'is_active' => true,
        ]);
    }

    public function test_cannot_reassign_tenant_id_on_update(): void
    {
        $tenantA = $this->createTenantFixture('tenant-a6', 'a6@test.local');
        $tenantB = $this->createTenantFixture('tenant-b6', 'b6@test.local');

        app(TenantContext::class)->bind($tenantA['tenant']);

        $customer = Customer::query()->findOrFail($tenantA['customer']->id);

        $this->expectException(ValidationException::class);

        $customer->update(['tenant_id' => $tenantB['tenant']->id]);
    }

    public function test_without_tenant_context_all_tenants_are_visible(): void
    {
        $this->createTenantFixture('tenant-a7', 'a7@test.local');
        $this->createTenantFixture('tenant-b7', 'b7@test.local');

        $this->assertGreaterThanOrEqual(2, Company::query()->withoutGlobalScopes()->count());
    }
}
