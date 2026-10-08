<?php

namespace Tests\Feature\Tax;

use App\Models\Tax;
use App\Models\TaxClass;
use App\Models\TaxGroup;
use App\Models\TaxRule;
use App\Services\Organization\CompanyTaxDefaults;
use App\Services\Tax\TaxEngine;
use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class TaxEngineTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_burundi_profile_is_installed_as_tenant_owned_data(): void
    {
        $fixture = $this->createTenantFixture('tax-bi', 'tax-bi@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);
        $fixture['tenant']->forceFill(['country_code' => 'BI'])->save();

        app(CompanyTaxDefaults::class)->ensure($fixture['tenant']->id);

        $this->assertDatabaseHas('taxes', [
            'tenant_id' => $fixture['tenant']->id,
            'code' => 'TVA18',
            'kind' => 'vat',
        ]);
        $this->assertDatabaseHas('taxes', [
            'tenant_id' => $fixture['tenant']->id,
            'code' => 'TVA0',
            'kind' => 'zero_rated',
        ]);
        $this->assertDatabaseHas('taxes', [
            'tenant_id' => $fixture['tenant']->id,
            'code' => 'EXO',
            'kind' => 'exempt',
        ]);
        $this->assertDatabaseHas('taxes', [
            'tenant_id' => $fixture['tenant']->id,
            'code' => 'RAS',
            'kind' => 'withholding',
        ]);
        $this->assertDatabaseHas('tax_classes', [
            'tenant_id' => $fixture['tenant']->id,
            'code' => 'STANDARD',
        ]);
        $this->assertDatabaseHas('tax_rules', [
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'Standard → TVA 18%',
        ]);
    }

    public function test_engine_calculates_vat_and_keeps_withholding_out_of_customer_total(): void
    {
        $fixture = $this->createTenantFixture('tax-calc', 'tax-calc@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $vat = Tax::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'TVA 18%',
            'code' => 'TVA18',
            'kind' => 'vat',
            'type' => 'percentage',
            'rate' => 18,
            'priority' => 10,
            'is_inclusive' => false,
            'is_compound' => false,
            'is_active' => true,
        ]);
        $withholding = Tax::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'RAS 2%',
            'code' => 'RAS2',
            'kind' => 'withholding',
            'type' => 'percentage',
            'rate' => 2,
            'priority' => 30,
            'is_inclusive' => false,
            'is_compound' => false,
            'is_active' => true,
        ]);

        $result = app(TaxEngine::class)->calculate(
            amount: 10_000,
            amountIsInclusive: false,
            taxIds: [$vat->id, $withholding->id],
        );

        $this->assertSame(10_000, $result['net']);
        $this->assertSame(1_800, $result['tax_total']);
        $this->assertSame(200, $result['withholding_total']);
        $this->assertSame(11_800, $result['total']);
        $this->assertCount(2, $result['lines']);
    }

    public function test_rules_resolve_taxes_by_class_without_hardcoded_country_logic(): void
    {
        $fixture = $this->createTenantFixture('tax-rules', 'tax-rules@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $vat = Tax::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'TVA 18%',
            'code' => 'TVA18',
            'kind' => 'vat',
            'rate' => 18,
            'priority' => 10,
            'is_active' => true,
        ]);
        $zero = Tax::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'Zero',
            'code' => 'TVA0',
            'kind' => 'zero_rated',
            'rate' => 0,
            'priority' => 10,
            'is_active' => true,
        ]);
        $standard = TaxClass::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'Standard',
            'code' => 'STANDARD',
            'is_active' => true,
        ]);
        $zeroClass = TaxClass::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'Zero',
            'code' => 'ZERO',
            'is_active' => true,
        ]);
        TaxRule::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'Std',
            'tax_class_id' => $standard->id,
            'tax_id' => $vat->id,
            'country' => 'BI',
            'priority' => 10,
            'is_active' => true,
        ]);
        TaxRule::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'Zero rule',
            'tax_class_id' => $zeroClass->id,
            'tax_id' => $zero->id,
            'country' => 'BI',
            'priority' => 10,
            'is_active' => true,
        ]);

        $engine = app(TaxEngine::class);
        $std = $engine->calculate(amount: 5_000, taxClassId: $standard->id, country: 'BI');
        $zr = $engine->calculate(amount: 5_000, taxClassId: $zeroClass->id, country: 'BI');

        $this->assertSame(900, $std['tax_total']);
        $this->assertSame(0, $zr['tax_total']);
        $this->assertSame('zero_rated', $zr['lines'][0]['kind']);
    }

    public function test_api_supports_groups_classes_rules_and_calculate(): void
    {
        $fixture = $this->createTenantFixture('tax-api', 'tax-api@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $tax = $this->postJson('/api/v1/taxes', [
            'name' => 'TVA 18%',
            'code' => 'TVA18',
            'kind' => 'vat',
            'rate' => 18,
            'priority' => 10,
        ], $headers)->assertCreated()->json('data');

        $group = $this->postJson('/api/v1/tax-groups', [
            'name' => 'Vente',
            'code' => 'SALE',
            'tax_ids' => [$tax['id']],
        ], $headers)->assertCreated()->json('data');

        $class = $this->postJson('/api/v1/tax-classes', [
            'name' => 'Standard',
            'code' => 'STANDARD',
        ], $headers)->assertCreated()->json('data');

        $this->postJson('/api/v1/tax-rules', [
            'name' => 'Std BI',
            'tax_class_id' => $class['id'],
            'tax_group_id' => $group['id'],
            'country' => 'BI',
            'priority' => 5,
        ], $headers)->assertCreated();

        $this->postJson('/api/v1/taxes/calculate', [
            'amount' => 10_000,
            'amount_is_inclusive' => false,
            'tax_group_id' => $group['id'],
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.tax_total', 1800)
            ->assertJsonPath('data.total', 11800);

        $this->getJson('/api/v1/tax-profiles', $headers)
            ->assertOk()
            ->assertJsonFragment(['key' => 'BI']);

        $this->assertTrue(TaxGroup::query()->where('id', $group['id'])->exists());
        $this->assertTrue(TaxClass::query()->where('id', $class['id'])->exists());
        $this->assertTrue(TaxRule::query()->where('tax_class_id', $class['id'])->exists());
    }

    public function test_compound_tax_applies_on_previous_tax_base(): void
    {
        $fixture = $this->createTenantFixture('tax-compound', 'tax-compound@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $vat = Tax::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'TVA',
            'code' => 'TVA',
            'kind' => 'vat',
            'rate' => 10,
            'priority' => 10,
            'is_active' => true,
        ]);
        $local = Tax::query()->create([
            'tenant_id' => $fixture['tenant']->id,
            'name' => 'TC',
            'code' => 'TC',
            'kind' => 'tax',
            'rate' => 5,
            'priority' => 20,
            'is_compound' => true,
            'is_active' => true,
        ]);

        $result = app(TaxEngine::class)->calculate(
            amount: 10_000,
            taxIds: [$vat->id, $local->id],
        );

        // 10% of 10000 = 1000; compound 5% of 11000 = 550 → tax_total 1550
        $this->assertSame(1_550, $result['tax_total']);
        $this->assertSame(11_550, $result['total']);
    }
}
