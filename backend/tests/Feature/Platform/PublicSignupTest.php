<?php

namespace Tests\Feature\Platform;

use App\Mail\BusinessNotificationMail;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Auth\AuthTokenService;
use App\Services\Rbac\RoleProvisioningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PublicSignupTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_signup_creates_a_pending_company_and_emails_credentials(): void
    {
        Mail::fake();

        $this->postJson('/api/v1/public/signup', [
            'company_name' => 'Old Pentagone',
            'admin_name' => 'Aline Admin',
            'email' => 'aline@old-pentagone.test',
            'phone' => '+25770000000',
            'password' => 'secret-pass',
            'password_confirmation' => 'secret-pass',
            'plan' => 'business',
        ])->assertCreated()
            ->assertJsonPath('data.tenant.slug', 'old-pentagone')
            ->assertJsonPath('data.email', 'aline@old-pentagone.test');

        $tenant = Tenant::query()->where('slug', 'old-pentagone')->firstOrFail();
        $this->assertTrue((bool) data_get($tenant->settings, 'signup.awaiting_approval'));
        $this->assertSame('business', data_get($tenant->settings, 'signup.requested_plan'));
        $this->assertNotNull(User::query()->where('email', 'aline@old-pentagone.test')->first());

        Mail::assertSent(BusinessNotificationMail::class, function (BusinessNotificationMail $mail) {
            return str_contains($mail->bodyText, 'Vous avez bien souscrit')
                && str_contains($mail->bodyText, 'aline@old-pentagone.test')
                && str_contains($mail->bodyText, 'secret-pass')
                && str_contains($mail->bodyText, 'old-pentagone');
        });
    }

    public function test_super_admin_approves_the_requested_plan(): void
    {
        Mail::fake();
        $this->postJson('/api/v1/public/signup', [
            'company_name' => 'Maison Test',
            'admin_name' => 'Nora',
            'email' => 'nora@maison-test.test',
            'password' => 'secret-pass',
            'password_confirmation' => 'secret-pass',
            'plan' => 'professional',
        ])->assertCreated();

        $tenant = Tenant::query()->where('slug', 'maison-test')->firstOrFail();
        $this->seed(\Database\Seeders\PermissionSeeder::class);
        $role = app(RoleProvisioningService::class)->provisionSuperAdminRole();
        $admin = User::create([
            'tenant_id' => null,
            'name' => 'Platform',
            'email' => 'platform-signup@test.local',
            'password' => Hash::make('password'),
            'is_active' => true,
        ]);
        $admin->roles()->attach($role->id, ['branch_id' => null, 'store_id' => null]);
        $token = app(AuthTokenService::class)->issue($admin)['access_token'];

        $this->postJson('/api/v1/platform/tenants/'.$tenant->id.'/signup/approve', [], [
            'Authorization' => 'Bearer '.$token,
            'Accept' => 'application/json',
        ])->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.plan', 'professional');

        $tenant->refresh();
        $this->assertFalse((bool) data_get($tenant->settings, 'signup.awaiting_approval'));
        $this->assertSame('active', $tenant->status);
    }
}
