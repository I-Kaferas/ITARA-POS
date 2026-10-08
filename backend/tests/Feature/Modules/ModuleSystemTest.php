<?php

namespace Tests\Feature\Modules;

use App\Services\Authorization\AuthorizationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class ModuleSystemTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_disabled_modules_are_not_loaded_and_their_routes_are_rejected(): void
    {
        $fixture = $this->createTenantFixture('mod-a', 'mod-a@test.local');
        $this->limitModules($fixture['tenant'], ['pos']);
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $manifest = $this->getJson('/api/v1/modules', $headers)->assertOk();
        $codes = collect($manifest->json('data'))->pluck('code')->all();
        $this->assertSame(['pos'], $codes);
        $this->assertNotEmpty($manifest->json('data.0.permissions'));
        $this->assertNotEmpty($manifest->json('data.0.navigation'));
        $this->assertNotEmpty($manifest->json('data.0.widgets'));
        $this->assertNotEmpty($manifest->json('data.0.routes.web'));
        $this->assertSame('allow_price_override', $manifest->json('data.0.settings.0.key'));
        $catalogCodes = collect($manifest->json('catalog'))->pluck('code')->all();
        $this->assertSame(['pos'], $catalogCodes);
        $this->assertNull(collect($manifest->json('catalog'))->firstWhere('code', 'crm'));
        $this->assertNull(collect($manifest->json('catalog'))->firstWhere('code', 'inventory'));

        $this->getJson('/api/v1/crm/overview', $headers)
            ->assertForbidden()
            ->assertJsonPath('code', 'errors.module_disabled')
            ->assertJsonPath('message', 'errors.module_disabled')
            ->assertJsonPath('module', 'crm');

        $sales = $this->getJson('/api/v1/sales', $headers);
        $this->assertNotSame('errors.module_disabled', $sales->json('message'));

        $this->putJson('/api/v1/modules/crm/settings', ['pipeline_name' => 'Nord'], $headers)
            ->assertForbidden();

        $this->putJson('/api/v1/modules/pos/settings', [
            'allow_price_override' => false,
            'require_shift' => true,
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.settings.allow_price_override', false);

        $this->putJson('/api/v1/modules/pos', ['enabled' => false], $headers)
            ->assertStatus(422);

        $fixture['user']->refresh();
        $auth = app(AuthorizationService::class);
        $this->assertTrue($auth->hasPermission($fixture['user'], 'sales.view'));
        $this->assertFalse($auth->hasPermission($fixture['user'], 'inventory.view'));
        $this->assertFalse($auth->hasPermission($fixture['user'], 'crm.view'));

        $groups = collect($this->getJson('/api/v1/permissions', $headers)->assertOk()->json('data'))->pluck('group');
        $this->assertTrue($groups->contains('sales'));
        $this->assertFalse($groups->contains('expenses'));
        $this->assertFalse($groups->contains('crm'));
    }

    public function test_unassigned_modules_stay_unloaded_until_the_tenant_enables_them(): void
    {
        $fixture = $this->createTenantFixture('mod-c', 'mod-c@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $codes = collect($this->getJson('/api/v1/modules', $headers)->assertOk()->json('data'))->pluck('code');
        $this->assertTrue($codes->contains('crm'));
        $this->assertTrue($codes->contains('pos'));
        $this->assertFalse($codes->contains('hr'));
        $this->assertFalse($codes->contains('fleet'));
        $this->assertFalse($codes->contains('ecommerce'));

        $crm = $this->getJson('/api/v1/crm/overview', $headers);
        $this->assertNotSame('errors.module_disabled', $crm->json('message'));

        $this->putJson('/api/v1/modules/hr', ['enabled' => true], $headers)
            ->assertOk();

        $enabled = collect($this->getJson('/api/v1/modules', $headers)->assertOk()->json('data'))->pluck('code');
        $this->assertTrue($enabled->contains('hr'));
        $this->assertFalse($enabled->contains('fleet'));
    }

    public function test_stock_alias_enables_inventory_and_hides_disabled_widgets(): void
    {
        $fixture = $this->createTenantFixture('mod-b', 'mod-b@test.local');
        $this->limitModules($fixture['tenant'], ['stock', 'hotel']);
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $manifest = $this->getJson('/api/v1/modules', $headers)->assertOk();
        $this->assertEqualsCanonicalizing(
            ['inventory', 'hotel'],
            collect($manifest->json('data'))->pluck('code')->all(),
        );
        $widgetCodes = collect($manifest->json('data'))->flatMap(fn (array $module) => collect($module['widgets'])->pluck('code'))->all();
        $this->assertContains('inventory.home', $widgetCodes);
        $this->assertContains('hotel.home', $widgetCodes);
        $this->assertNotContains('pos.home', $widgetCodes);

        $alerts = $this->getJson('/api/v1/inventory/alerts', $headers);
        $this->assertNotSame('errors.module_disabled', $alerts->json('message'));

        $this->getJson('/api/v1/crm/leads', $headers)
            ->assertForbidden()
            ->assertJsonPath('module', 'crm');
    }

    private function limitModules(\App\Models\Tenant $tenant, array $modules): void
    {
        $settings = $tenant->settings ?? [];
        $settings['saas']['modules'] = $modules;
        $tenant->settings = $settings;
        $tenant->save();
    }
}
