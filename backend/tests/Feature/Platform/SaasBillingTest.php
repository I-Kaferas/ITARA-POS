<?php

namespace Tests\Feature\Platform;

use App\Models\Role;
use App\Models\SaasPlan;
use App\Models\SaasSubscription;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Auth\AuthTokenService;
use App\Services\Platform\SaasSubscriptionService;
use App\Services\Rbac\RoleProvisioningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class SaasBillingTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_commercial_plans_trial_upgrade_invoice_and_payment(): void
    {
        $fixture = $this->createTenantFixture('saas-bill', 'saas-bill@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $platform = $this->platformHeaders();

        $catalog = $this->getJson('/api/v1/platform/plans', $platform)
            ->assertOk()
            ->json('data');
        $this->assertSame(['starter', 'professional', 'business', 'enterprise'], collect($catalog)->pluck('code')->all());

        $this->patchJson('/api/v1/platform/plans/starter', [
            'limits' => ['users' => 8],
        ], $platform)
            ->assertOk()
            ->assertJsonPath('data.limits.users', 8);

        $this->patchJson('/api/v1/tenant/subscription', ['plan' => 'professional'], $headers)
            ->assertOk()
            ->assertJsonPath('data.plan', 'professional')
            ->assertJsonPath('data.status', 'trial');

        $subscribed = $this->postJson('/api/v1/tenant/subscription/subscribe', [
            'plan' => 'professional',
            'billing_cycle' => 'monthly',
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.plan', 'professional')
            ->assertJsonPath('data.billing_cycle', 'monthly')
            ->assertJsonPath('data.invoices.0.status', 'open')
            ->assertJsonPath('data.invoices.0.amount', 1500);

        $invoiceId = $subscribed->json('data.invoices.0.id');

        $this->postJson('/api/v1/platform/invoices/'.$invoiceId.'/payments', [
            'method' => 'transfer',
            'reference' => 'VIR-100',
            'status' => 'succeeded',
        ], $platform)
            ->assertCreated()
            ->assertJsonPath('data.status', 'succeeded')
            ->assertJsonPath('data.invoice_status', 'paid');

        $this->getJson('/api/v1/tenant/subscription', $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.usage.users', 1)
            ->assertJsonPath('data.limits.users', 25);
    }

    public function test_downgrade_is_scheduled_until_usage_fits_and_period_ends(): void
    {
        $fixture = $this->createTenantFixture('saas-down', 'saas-down@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        app(SaasSubscriptionService::class)->startTrial($fixture['tenant'], 'professional');

        $subscription = SaasSubscription::query()->where('tenant_id', $fixture['tenant']->id)->firstOrFail();
        $subscription->forceFill([
            'status' => 'active',
            'period_starts_on' => now()->toDateString(),
            'period_ends_on' => now()->addMonth()->toDateString(),
        ])->save();

        $this->patchJson('/api/v1/tenant/subscription', ['plan' => 'starter'], $headers)
            ->assertOk()
            ->assertJsonPath('data.plan', 'professional')
            ->assertJsonPath('data.pending_plan', 'starter');

        $starter = SaasPlan::query()->where('code', 'starter')->firstOrFail();
        $limits = $starter->limits;
        $limits['users'] = 0;
        $starter->limits = $limits;
        $starter->save();

        $this->patchJson('/api/v1/tenant/subscription', ['plan' => 'starter'], $headers)
            ->assertStatus(422)
            ->assertJsonPath('errors.plan.0', 'saas.usage_exceeds_plan');

        $limits['users'] = 5;
        $starter->limits = $limits;
        $starter->save();
        $subscription->forceFill(['period_ends_on' => now()->subDay()->toDateString()])->save();

        $this->artisan('saas:reconcile')->assertSuccessful();

        $this->assertSame('starter', $subscription->fresh()->plan_code);
        $this->assertNull($subscription->fresh()->pending_plan_code);
    }

    public function test_limits_grace_and_suspension_block_the_workspace(): void
    {
        Carbon::setTestNow('2026-10-07 08:00:00');
        $fixture = $this->createTenantFixture('saas-grace', 'saas-grace@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $platform = $this->platformHeaders();
        app(SaasSubscriptionService::class)->startTrial($fixture['tenant'], 'starter');

        $starter = SaasPlan::query()->where('code', 'starter')->firstOrFail();
        $limits = $starter->limits;
        $limits['users'] = 1;
        $starter->limits = $limits;
        $starter->save();

        $this->postJson('/api/v1/users', [
            'name' => 'Extra',
            'email' => 'extra-saas@test.local',
            'password' => 'password123',
        ], $headers)->assertStatus(422)->assertJsonPath('errors.users.0', 'saas.limit_users');

        Carbon::setTestNow('2026-10-22 08:00:00');
        $this->artisan('saas:reconcile')->assertSuccessful();
        $subscription = SaasSubscription::query()->where('tenant_id', $fixture['tenant']->id)->firstOrFail();
        $this->assertSame('past_due', $subscription->status);
        $this->assertSame('2026-10-29', $subscription->grace_ends_on->toDateString());

        $headers = $this->tenantHeaders(app(AuthTokenService::class)->issue($fixture['user'])['access_token'], $fixture['tenant']);
        $this->getJson('/api/v1/users', $headers)->assertOk();

        Carbon::setTestNow('2026-10-30 08:00:00');
        $this->artisan('saas:reconcile')->assertSuccessful();
        $subscription->refresh();
        $fixture['tenant']->refresh();
        $this->assertSame('suspended', $subscription->status);
        $this->assertSame('suspended', $fixture['tenant']->status);

        $headers = $this->tenantHeaders(app(AuthTokenService::class)->issue($fixture['user'])['access_token'], $fixture['tenant']);
        $platform = $this->platformHeaders();
        $this->getJson('/api/v1/auth/me', $headers)->assertOk()->assertJsonPath('user.subscription.status', 'suspended');
        $this->getJson('/api/v1/tenant/subscription', $headers)->assertOk()->assertJsonPath('data.status', 'suspended');
        $this->getJson('/api/v1/users', $headers)->assertForbidden();

        $this->postJson('/api/v1/platform/tenants/'.$fixture['tenant']->id.'/subscription/grace', [], $platform)
            ->assertOk()
            ->assertJsonPath('data.status', 'past_due');
    }

    public function test_provisioning_opens_a_starter_trial(): void
    {
        $headers = $this->platformHeaders();

        $this->postJson('/api/v1/platform/tenants', [
            'name' => 'Boutique SaaS',
            'plan' => 'business',
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.tenant.status', 'trial');

        $tenant = Tenant::query()->where('slug', 'boutique-saas')->firstOrFail();
        $subscription = SaasSubscription::query()->where('tenant_id', $tenant->id)->firstOrFail();
        $this->assertSame('business', $subscription->plan_code);
        $this->assertSame('trial', $subscription->status);
        $this->assertNotNull($subscription->trial_ends_on);
        $this->assertContains('hotel', $tenant->fresh()->settings['saas']['modules']);
    }

    /** @return array<string, string> */
    private function platformHeaders(): array
    {
        $this->seed(\Database\Seeders\PermissionSeeder::class);
        $role = Role::query()->whereNull('tenant_id')->where('slug', 'super_admin')->first()
            ?? app(RoleProvisioningService::class)->provisionSuperAdminRole();
        $admin = User::query()->where('email', 'platform-saas@test.local')->first();
        if ($admin === null) {
            $admin = User::create([
                'tenant_id' => null,
                'name' => 'Platform SaaS',
                'email' => 'platform-saas@test.local',
                'password' => Hash::make('password'),
                'is_active' => true,
            ]);
            $admin->roles()->attach($role->id, ['branch_id' => null, 'store_id' => null]);
        }
        $token = app(AuthTokenService::class)->issue($admin)['access_token'];

        return [
            'Authorization' => 'Bearer '.$token,
            'Accept' => 'application/json',
        ];
    }
}
