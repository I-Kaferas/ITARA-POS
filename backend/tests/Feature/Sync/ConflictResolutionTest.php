<?php

namespace Tests\Feature\Sync;

use App\Enums\ConflictAction;
use App\Enums\ConflictDomain;
use App\Enums\ConflictStrategy;
use App\Enums\SaleStatus;
use App\Models\Sale;
use App\Services\Sync\ConflictContext;
use App\Services\Sync\ConflictResolutionEngine;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class ConflictResolutionTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private ConflictResolutionEngine $engine;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('conflict', 'conflict@test.local');
        $this->engine = app(ConflictResolutionEngine::class);
    }

    public function test_catalog_exposes_domain_strategies(): void
    {
        $catalog = $this->engine->catalog();

        $this->assertSame('never_overwrite_completed', $catalog['sales']['strategy']);
        $this->assertSame('stock_movements', $catalog['stock']['strategy']);
        $this->assertSame('master_wins', $catalog['configuration']['strategy']);
    }

    public function test_sales_never_overwrite_completed(): void
    {
        $reject = $this->engine->evaluate(ConflictContext::make(
            entityType: 'sale',
            operation: 'update',
            serverRecord: ['status' => 'completed'],
        ));

        $this->assertSame(ConflictAction::Reject, $reject->action);
        $this->assertSame('completed_sale', $reject->code);
        $this->assertSame(ConflictStrategy::NeverOverwriteCompleted, $reject->strategy);

        $pending = $this->engine->evaluate(ConflictContext::make(
            entityType: 'sale',
            operation: 'update',
            serverRecord: ['status' => 'pending'],
        ));
        $this->assertSame(ConflictAction::Apply, $pending->action);

        $keep = $this->engine->evaluate(ConflictContext::make(
            entityType: 'sale',
            operation: 'create',
            serverRecord: ['status' => 'completed'],
        ));
        $this->assertSame(ConflictAction::KeepServer, $keep->action);
    }

    public function test_stock_requires_movements(): void
    {
        $movement = $this->engine->evaluate(ConflictContext::make(
            entityType: 'stock_movement',
            operation: 'create',
            localPayload: ['quantity' => 5],
        ));
        $this->assertSame(ConflictAction::Apply, $movement->action);

        $overwrite = $this->engine->evaluate(ConflictContext::make(
            entityType: 'stock_balance',
            operation: 'set_quantity',
            localPayload: ['quantity_on_hand' => 40],
            serverRecord: ['quantity_on_hand' => 10],
        ));
        $this->assertSame(ConflictAction::RewriteAsMovement, $overwrite->action);
        $this->assertSame('use_stock_movements', $overwrite->code);
        $this->assertSame(30, $overwrite->meta['delta']);
    }

    public function test_configuration_master_wins(): void
    {
        $slave = $this->engine->evaluate(ConflictContext::make(
            entityType: 'product',
            operation: 'update',
            localPayload: ['name' => 'Local'],
            serverRecord: ['id' => 'master-1', 'name' => 'Master'],
            fromMaster: false,
        ));
        $this->assertSame(ConflictAction::KeepServer, $slave->action);
        $this->assertSame('master_wins', $slave->code);

        $master = $this->engine->evaluate(ConflictContext::make(
            entityType: 'tax',
            operation: 'update',
            localPayload: ['rate' => 18],
            serverRecord: ['id' => 'tax-1', 'rate' => 16],
            fromMaster: true,
        ));
        $this->assertSame(ConflictAction::Apply, $master->action);

        $merged = $this->engine->mergeConfiguration(
            ['name' => 'Master', 'nested' => ['a' => 1]],
            ['name' => 'Slave', 'nested' => ['a' => 2, 'b' => 3], 'extra' => true],
        );
        $this->assertSame('Master', $merged['name']);
        $this->assertSame(1, $merged['nested']['a']);
        $this->assertSame(3, $merged['nested']['b']);
        $this->assertTrue($merged['extra']);
    }

    public function test_domain_mapping_is_configurable(): void
    {
        $this->assertSame(ConflictDomain::Sales, $this->engine->resolveDomain(ConflictContext::make('sale', 'update')));
        $this->assertSame(ConflictDomain::Stock, $this->engine->resolveDomain(ConflictContext::make('inventory_movement', 'create')));
        $this->assertSame(ConflictDomain::Configuration, $this->engine->resolveDomain(ConflictContext::make('printer', 'update')));
        $this->assertSame(ConflictDomain::Default, $this->engine->resolveDomain(ConflictContext::make('unknown_thing', 'update')));
    }

    public function test_offline_sync_rejects_completed_sale_overwrite(): void
    {
        $headers = array_merge(
            $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']),
            ['X-Store-ID' => $this->fixture['store']->id],
        );

        $sale = Sale::query()->create([
            'tenant_id' => $this->fixture['store']->tenant_id,
            'store_id' => $this->fixture['store']->id,
            'warehouse_id' => $this->fixture['warehouse']->id,
            'processed_by' => $this->fixture['user']->id,
            'reference' => 'OFF-DONE',
            'status' => SaleStatus::Completed,
            'subtotal' => 1000,
            'tax_total' => 0,
            'discount_total' => 0,
            'fees_total' => 0,
            'total' => 1000,
            'currency' => 'FBU',
            'idempotency_key' => (string) Str::uuid(),
            'completed_at' => now(),
        ]);

        $uuid = (string) Str::uuid();
        $this->postJson('/api/v1/sync/offline', [
            'operations' => [[
                'id' => $uuid,
                'client_uuid' => $uuid,
                'domain' => 'pos',
                'entity_type' => 'sale',
                'entity_id' => $sale->id,
                'operation' => 'update',
                'payload' => [
                    'items' => [
                        ['product_id' => $this->fixture['product']->id, 'quantity' => 2],
                    ],
                ],
            ]],
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.results.0.status', 'conflict')
            ->assertJsonPath('data.results.0.conflict_code', 'completed_sale');

        $this->assertSame(SaleStatus::Completed, $sale->fresh()->status);
        $this->assertSame(1000, (int) $sale->fresh()->total);
    }

    public function test_offline_sync_rejects_stock_quantity_overwrite(): void
    {
        $headers = array_merge(
            $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']),
            ['X-Store-ID' => $this->fixture['store']->id],
        );

        $uuid = (string) Str::uuid();
        $this->postJson('/api/v1/sync/offline', [
            'operations' => [[
                'id' => $uuid,
                'client_uuid' => $uuid,
                'domain' => 'pos',
                'entity_type' => 'stock_balance',
                'entity_id' => $uuid,
                'operation' => 'set_quantity',
                'payload' => [
                    'quantity_on_hand' => 99,
                    'server_quantity' => 10,
                ],
            ]],
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.results.0.status', 'conflict')
            ->assertJsonPath('data.results.0.conflict_code', 'use_stock_movements');
    }

    public function test_references_include_conflict_resolution_catalog(): void
    {
        $headers = array_merge(
            $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']),
            ['X-Store-ID' => $this->fixture['store']->id],
        );

        $this->getJson('/api/v1/sync/references', $headers)
            ->assertOk()
            ->assertJsonPath('data.conflict_resolution.sales.strategy', 'never_overwrite_completed')
            ->assertJsonPath('data.conflict_resolution.stock.strategy', 'stock_movements')
            ->assertJsonPath('data.conflict_resolution.configuration.strategy', 'master_wins');
    }
}
