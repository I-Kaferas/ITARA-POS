<?php

namespace Tests\Feature\Catalog;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class CatalogDefaultLimitTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_only_one_catalog_can_be_default(): void
    {
        $fixture = $this->createTenantFixture('cat-default', 'cat-default@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $companyId = $fixture['company']->id;

        $this->assertTrue($fixture['catalog']->is_default);

        $second = $this->postJson("/api/v1/companies/{$companyId}/catalogs", [
            'name' => 'Catalogue secondaire',
            'is_default' => true,
            'is_active' => true,
        ], $headers)->assertCreated();

        $this->assertTrue($second->json('data.is_default'));
        $this->assertFalse($fixture['catalog']->fresh()->is_default);

        $thirdId = $this->postJson("/api/v1/companies/{$companyId}/catalogs", [
            'name' => 'Catalogue tertiaire',
            'is_default' => false,
            'is_active' => true,
        ], $headers)->assertCreated()->json('data.id');

        $this->patchJson("/api/v1/catalogs/{$thirdId}", [
            'is_default' => true,
        ], $headers)->assertOk()->assertJsonPath('data.is_default', true);

        $this->assertFalse($fixture['catalog']->fresh()->is_default);
        $this->assertFalse(
            $fixture['company']->catalogs()->find($second->json('data.id'))->fresh()->is_default,
        );
        $this->assertSame(
            1,
            $fixture['company']->catalogs()->where('is_default', true)->count(),
        );
    }
}
