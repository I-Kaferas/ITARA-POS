<?php

namespace Tests\Support;

use App\Models\Branch;
use App\Models\Catalog;
use App\Models\Company;
use App\Models\Currency;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\Store;
use App\Models\Supplier;
use App\Models\Tenant;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Auth\AuthTokenService;
use App\Services\Rbac\RoleProvisioningService;
use Illuminate\Support\Facades\Hash;

trait InteractsWithTenants
{
    /**
     * @return array{tenant: Tenant, user: User, token: string, refresh_token: string, company: Company, catalog: Catalog, branch: Branch, store: Store, warehouse: Warehouse, product: Product, customer: Customer, supplier: Supplier}
     */
    protected function createTenantFixture(string $slug, string $email): array
    {
        $this->seed(\Database\Seeders\PermissionSeeder::class);

        $tenant = Tenant::create([
            'name' => "Tenant {$slug}",
            'slug' => $slug,
            'status' => 'active',
        ]);

        app(RoleProvisioningService::class)->provisionForTenant($tenant);

        $user = User::create([
            'tenant_id' => $tenant->id,
            'name' => "User {$slug}",
            'email' => $email,
            'password' => Hash::make('password'),
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        $adminRole = Role::query()
            ->where('tenant_id', $tenant->id)
            ->where('slug', 'administrator')
            ->firstOrFail();

        $user->roles()->attach($adminRole->id, [
            'branch_id' => null,
            'store_id' => null,
        ]);

        $issued = app(AuthTokenService::class)->issue($user);

        $company = Company::create([
            'tenant_id' => $tenant->id,
            'name' => "Company {$slug}",
            'currency_code' => 'FBU',
            'is_active' => true,
        ]);

        Currency::create([
            'tenant_id' => $tenant->id,
            'code' => 'FBU',
            'name' => 'Franc Burundais',
            'symbol' => 'FBu',
            'decimal_places' => 0,
            'exchange_rate' => 1,
            'is_default' => true,
            'is_active' => true,
        ]);

        $catalog = Catalog::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'Catalogue',
            'is_default' => true,
            'is_active' => true,
        ]);

        $branch = Branch::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'Branch',
            'code' => strtoupper($slug),
            'is_active' => true,
        ]);

        $store = Store::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Store',
            'code' => strtoupper($slug).'01',
            'is_active' => true,
        ]);

        app(\App\Services\Catalog\StoreCatalogService::class)->ensureUnits($store);

        $warehouse = Warehouse::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Warehouse',
            'code' => strtoupper($slug).'-WH',
            'is_active' => true,
        ]);

        $product = Product::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'sku' => strtoupper($slug).'-001',
            'name' => "Product {$slug}",
            'base_price' => 1000,
            'is_active' => true,
        ]);

        $customer = Customer::create([
            'tenant_id' => $tenant->id,
            'name' => "Customer {$slug}",
            'email' => "customer-{$slug}@test.local",
            'is_active' => true,
        ]);

        $supplier = Supplier::create([
            'tenant_id' => $tenant->id,
            'name' => "Supplier {$slug}",
            'code' => strtoupper($slug).'-SUP',
            'is_active' => true,
        ]);

        return [
            'tenant' => $tenant,
            'user' => $user,
            'token' => $issued['access_token'],
            'refresh_token' => $issued['refresh_token'],
            'company' => $company,
            'catalog' => $catalog,
            'branch' => $branch,
            'store' => $store,
            'warehouse' => $warehouse,
            'product' => $product,
            'customer' => $customer,
            'supplier' => $supplier,
        ];
    }

    protected function tenantHeaders(string $token, Tenant $tenant): array
    {
        return [
            'Authorization' => 'Bearer '.$token,
            'X-Tenant-ID' => $tenant->id,
            'Accept' => 'application/json',
        ];
    }
}
