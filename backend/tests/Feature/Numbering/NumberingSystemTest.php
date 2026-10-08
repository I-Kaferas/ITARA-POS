<?php

namespace Tests\Feature\Numbering;

use App\Enums\NumberingDocumentType;
use App\Models\Branch;
use App\Models\NumberingSequence;
use App\Services\Numbering\ReferenceNumberGenerator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class NumberingSystemTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('numbering', 'numbering@test.local');
        $this->travelTo(now()->setDate(2026, 3, 15)->setTime(12, 0));
    }

    public function test_defaults_match_documented_formats(): void
    {
        $generator = app(ReferenceNumberGenerator::class);
        $tenantId = $this->fixture['tenant']->id;
        $branchId = $this->fixture['branch']->id;

        $this->assertSame('INV-2026-000001', $generator->next(NumberingDocumentType::Invoice, $tenantId, $branchId));
        $this->assertSame('POS-2026-000001', $generator->next(NumberingDocumentType::Pos, $tenantId, $branchId));
        $this->assertSame('PO-2026-000001', $generator->next(NumberingDocumentType::PurchaseOrder, $tenantId, $branchId));
        $this->assertSame('RES-2026-000001', $generator->next(NumberingDocumentType::Reservation, $tenantId, $branchId));
        $this->assertSame('EXP-2026-000001', $generator->next(NumberingDocumentType::Expense, $tenantId, $branchId));
    }

    public function test_sequences_increment_and_preview_does_not_consume(): void
    {
        $generator = app(ReferenceNumberGenerator::class);
        $tenantId = $this->fixture['tenant']->id;

        $this->assertSame('POS-2026-000001', $generator->preview(NumberingDocumentType::Pos, $tenantId));
        $this->assertSame('POS-2026-000001', $generator->next(NumberingDocumentType::Pos, $tenantId));
        $this->assertSame('POS-2026-000002', $generator->preview(NumberingDocumentType::Pos, $tenantId));
        $this->assertSame('POS-2026-000002', $generator->next(NumberingDocumentType::Pos, $tenantId));
    }

    public function test_branch_rule_overrides_tenant_and_uses_own_counter(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $tenantId = $this->fixture['tenant']->id;
        $branchA = $this->fixture['branch'];
        $branchB = Branch::query()->create([
            'tenant_id' => $tenantId,
            'company_id' => $this->fixture['company']->id,
            'name' => 'Branch B',
            'code' => 'BRB',
            'is_active' => true,
        ]);

        $this->postJson('/api/v1/numbering/rules', [
            'document_type' => 'pos',
            'prefix' => 'POS',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 6,
            'reset_policy' => 'yearly',
            'starting_number' => 1,
        ], $headers)->assertCreated();

        $this->postJson('/api/v1/numbering/rules', [
            'document_type' => 'pos',
            'branch_id' => $branchB->id,
            'prefix' => 'POSB',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 6,
            'reset_policy' => 'yearly',
            'starting_number' => 45,
        ], $headers)->assertCreated();

        $generator = app(ReferenceNumberGenerator::class);

        $this->assertSame('POS-2026-000001', $generator->next(NumberingDocumentType::Pos, $tenantId, $branchA->id));
        $this->assertSame('POSB-2026-000045', $generator->next(NumberingDocumentType::Pos, $tenantId, $branchB->id));
        $this->assertSame('POS-2026-000002', $generator->next(NumberingDocumentType::Pos, $tenantId, $branchA->id));
        $this->assertSame('POSB-2026-000046', $generator->next(NumberingDocumentType::Pos, $tenantId, $branchB->id));
    }

    public function test_api_catalog_preview_and_crud(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $index = $this->getJson('/api/v1/numbering', $headers)->assertOk();
        $catalog = collect($index->json('data.catalog'));
        $this->assertTrue($catalog->contains(fn ($row) => $row['document_type'] === 'invoice' && $row['prefix'] === 'INV'));
        $this->assertTrue($catalog->contains(fn ($row) => $row['document_type'] === 'pos' && str_starts_with($row['preview'], 'POS-2026-')));

        $this->postJson('/api/v1/numbering/preview', [
            'document_type' => 'expense',
        ], $headers)->assertOk()
            ->assertJsonPath('data.reference', 'EXP-2026-000001');

        $created = $this->postJson('/api/v1/numbering/rules', [
            'document_type' => 'expense',
            'prefix' => 'DEP',
            'pattern' => '{prefix}-{year}-{sequence}',
            'padding' => 4,
            'reset_policy' => 'yearly',
            'starting_number' => 56,
        ], $headers)->assertCreated();

        $ruleId = $created->json('data.id');

        $this->putJson("/api/v1/numbering/rules/{$ruleId}", [
            'prefix' => 'EXP',
            'padding' => 6,
            'starting_number' => 56,
        ], $headers)->assertOk()
            ->assertJsonPath('data.prefix', 'EXP')
            ->assertJsonPath('data.padding', 6);

        $this->assertSame(
            'EXP-2026-000056',
            app(ReferenceNumberGenerator::class)->next(
                NumberingDocumentType::Expense,
                $this->fixture['tenant']->id,
            ),
        );

        $this->deleteJson("/api/v1/numbering/rules/{$ruleId}", [], $headers)->assertOk();
        $this->assertDatabaseMissing('numbering_rules', ['id' => $ruleId]);
    }

    public function test_yearly_reset_uses_distinct_period_keys(): void
    {
        $generator = app(ReferenceNumberGenerator::class);
        $tenantId = $this->fixture['tenant']->id;

        $this->assertSame('INV-2026-000001', $generator->next(NumberingDocumentType::Invoice, $tenantId, null, '2026-01-01'));
        $this->assertSame('INV-2027-000001', $generator->next(NumberingDocumentType::Invoice, $tenantId, null, '2027-01-01'));

        $this->assertSame(2, NumberingSequence::query()->where('document_type', 'invoice')->count());
    }
}
