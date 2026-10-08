<?php

namespace Tests\Feature\Tenancy;

use App\Notifications\ResetPasswordNotification;
use App\Services\Organization\TenantProvisioningService;
use App\Services\Reports\ReportService;
use App\Tenancy\BindTenant;
use App\Tenancy\TenantCache;
use App\Tenancy\TenantContext;
use App\Tenancy\TenantStorage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class TenantAwarenessTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_provisioning_stores_the_legal_profile_on_the_tenant(): void
    {
        $this->seed(\Database\Seeders\PermissionSeeder::class);

        $created = app(TenantProvisioningService::class)->provision([
            'name' => 'Maison Legal',
            'legal_name' => 'Maison Legal SPRL',
            'trade_name' => 'Maison',
            'email' => 'hi@maison.test',
            'phone' => '+25722000000',
            'website' => 'https://maison.test',
            'country_code' => 'BI',
            'currency_code' => 'FBU',
            'locale' => 'fr',
            'timezone' => 'Africa/Bujumbura',
            'tax_regime' => 'VAT',
            'tax_id' => '4001732983',
            'registration_number' => 'RC-31453',
            'address' => ['city' => 'Bujumbura'],
        ]);

        $profile = $created['tenant']->fresh()->profile();

        $this->assertSame('Maison Legal SPRL', $profile['legal_name']);
        $this->assertSame('Maison', $profile['trade_name']);
        $this->assertSame('BI', $profile['country_code']);
        $this->assertSame('FBU', $profile['currency_code']);
        $this->assertSame('VAT', $profile['tax_regime']);
        $this->assertSame('4001732983', $profile['tax_id']);
        $this->assertSame('trial', $profile['status']);
        $this->assertNotNull($profile['created_at']);
        $this->assertSame('pos_stock', $profile['subscription']['plan']);
    }

    public function test_cache_entries_do_not_cross_tenants(): void
    {
        $tenantA = $this->createTenantFixture('cache-a', 'cache-a@test.local');
        $tenantB = $this->createTenantFixture('cache-b', 'cache-b@test.local');
        $cache = app(TenantCache::class);
        $context = app(TenantContext::class);

        $context->bind($tenantA['tenant']);
        $cache->put('marker', 'secret-a', 60);

        $context->bind($tenantB['tenant']);
        $this->assertNull($cache->get('marker'));

        $context->bind($tenantA['tenant']);
        $this->assertSame('secret-a', $cache->get('marker'));
    }

    public function test_files_outside_the_tenant_directory_are_rejected(): void
    {
        $tenantA = $this->createTenantFixture('files-a', 'files-a@test.local');
        $tenantB = $this->createTenantFixture('files-b', 'files-b@test.local');
        app(TenantContext::class)->bind($tenantA['tenant']);

        $storage = app(TenantStorage::class);
        $this->assertSame(
            'tenants/'.$tenantA['tenant']->id.'/receipts/z.pdf',
            $storage->path('receipts/z.pdf'),
        );

        $this->expectException(RuntimeException::class);
        $storage->assertOwned($tenantB['tenant']->id.'/products/photo.jpg');
    }

    public function test_job_middleware_restores_only_its_tenant(): void
    {
        $tenantA = $this->createTenantFixture('job-a', 'job-a@test.local');
        $job = new class($tenantA['tenant']->id)
        {
            public function __construct(public string $tenantId) {}
        };

        app(TenantContext::class)->clear();
        $seen = null;
        (new BindTenant)->handle($job, function () use (&$seen): void {
            $seen = app(TenantContext::class)->id();
        });

        $this->assertSame($tenantA['tenant']->id, $seen);
        $this->assertFalse(app(TenantContext::class)->isBound());
    }

    public function test_notification_is_dropped_for_a_foreign_tenant(): void
    {
        $tenantA = $this->createTenantFixture('mail-a', 'mail-a@test.local');
        $tenantB = $this->createTenantFixture('mail-b', 'mail-b@test.local');
        app(TenantContext::class)->bind($tenantA['tenant']);

        $channels = (new ResetPasswordNotification('token'))->via($tenantB['user']);

        $this->assertSame([], $channels);
    }

    public function test_report_refuses_to_run_without_a_tenant(): void
    {
        app(TenantContext::class)->clear();

        $this->expectException(RuntimeException::class);
        app(ReportService::class)->salesSummary(null, null, null, false);
    }
};
