<?php

namespace Tests\Feature\Platform;

use App\Models\PlatformBackup;
use App\Models\Role;
use App\Models\User;
use App\Services\Auth\AuthTokenService;
use App\Services\Platform\Backup\BackupService;
use App\Services\Rbac\RoleProvisioningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class BackupRecoveryTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_tenant_user_cannot_access_platform_backups(): void
    {
        $fixture = $this->createTenantFixture('backup-deny', 'backup-deny@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $this->getJson('/api/v1/platform/backups', $headers)->assertForbidden();
        $this->postJson('/api/v1/platform/backups', ['type' => 'full'], $headers)->assertForbidden();
    }

    public function test_platform_admin_can_backup_verify_dry_run_and_manage_policy(): void
    {
        Storage::fake('public');
        Storage::disk('public')->put('tenants/demo/products/sample.txt', 'product-image');
        config([
            'backup.file_sources' => [
                ['disk' => 'public', 'path' => ''],
            ],
        ]);

        $platform = $this->platformHeaders();

        $created = $this->postJson('/api/v1/platform/backups', ['type' => 'full'], $platform)
            ->assertCreated()
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.type', 'full')
            ->assertJsonPath('data.includes.database', true)
            ->assertJsonPath('data.includes.files', true);

        $backupId = $created->json('data.id');
        $this->assertNotEmpty($created->json('data.checksum'));
        $this->assertGreaterThan(0, $created->json('data.size_bytes'));

        $this->getJson('/api/v1/platform/backups', $platform)
            ->assertOk()
            ->assertJsonPath('data.0.id', $backupId)
            ->assertJsonStructure(['policy' => ['retention', 'auto_enabled'], 'disaster_recovery' => ['checklist', 'runbook']]);

        $this->postJson('/api/v1/platform/backups/'.$backupId.'/verify', [], $platform)
            ->assertOk()
            ->assertJsonPath('data.id', $backupId);

        $this->assertNotNull(PlatformBackup::query()->findOrFail($backupId)->verified_at);

        $this->postJson('/api/v1/platform/backups/'.$backupId.'/restore', [
            'mode' => 'dry_run',
            'database' => true,
            'files' => true,
        ], $platform)
            ->assertOk()
            ->assertJsonPath('data.mode', 'dry_run')
            ->assertJsonPath('data.status', 'completed');

        $this->postJson('/api/v1/platform/backups/'.$backupId.'/restore', [
            'mode' => 'live',
            'database' => true,
        ], $platform)->assertStatus(422);

        $this->patchJson('/api/v1/platform/backups/policy', [
            'auto_enabled' => true,
            'schedule_time' => '04:15',
            'keep_daily' => 3,
            'keep_weekly' => 2,
            'keep_monthly' => 1,
            'rpo_hours' => 24,
        ], $platform)
            ->assertOk()
            ->assertJsonPath('data.schedule_time', '04:15')
            ->assertJsonPath('data.retention.daily', 3);

        $this->getJson('/api/v1/platform/backups/disaster-recovery', $platform)
            ->assertOk()
            ->assertJsonPath('data.within_rpo', true)
            ->assertJsonPath('data.last_backup.id', $backupId);

        $this->artisan('backups:verify', ['backup' => $backupId])->assertSuccessful();
        $this->artisan('backups:prune')->assertSuccessful();
    }

    public function test_scheduled_backup_command_respects_auto_enabled(): void
    {
        $service = app(BackupService::class);
        $service->updateSettings(['auto_enabled' => false]);

        $this->artisan('backups:run')->assertSuccessful();
        $this->assertSame(0, PlatformBackup::query()->count());

        $this->artisan('backups:run', ['--force' => true, '--type' => 'database'])->assertSuccessful();
        $this->assertSame(1, PlatformBackup::query()->where('type', 'database')->count());
    }

    public function test_retention_keeps_recent_backups_only(): void
    {
        $service = app(BackupService::class);
        $service->updateSettings([
            'keep_daily' => 2,
            'keep_weekly' => 0,
            'keep_monthly' => 0,
        ]);

        $first = $service->create('database', 'manual');
        $this->travel(1)->hours();
        $second = $service->create('database', 'manual');
        $this->travel(1)->hours();
        $third = $service->create('database', 'manual');

        $this->assertFalse(PlatformBackup::query()->whereKey($first->id)->exists());
        $this->assertTrue(PlatformBackup::query()->whereKey($second->id)->exists());
        $this->assertTrue(PlatformBackup::query()->whereKey($third->id)->exists());
    }

    /** @return array<string, string> */
    private function platformHeaders(): array
    {
        $this->seed(\Database\Seeders\PermissionSeeder::class);
        $role = Role::query()->whereNull('tenant_id')->where('slug', 'super_admin')->first()
            ?? app(RoleProvisioningService::class)->provisionSuperAdminRole();
        $admin = User::query()->where('email', 'platform-backup@test.local')->first();
        if ($admin === null) {
            $admin = User::create([
                'tenant_id' => null,
                'name' => 'Platform Backup',
                'email' => 'platform-backup@test.local',
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
