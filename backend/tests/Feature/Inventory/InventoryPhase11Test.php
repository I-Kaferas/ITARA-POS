<?php

namespace Tests\Feature\Inventory;

use App\Enums\InventoryMovementType;
use App\Models\StockBalance;
use App\Models\Warehouse;
use App\Services\Inventory\InventoryMovementService;
use App\Services\Inventory\StockAdjustmentService;
use App\Services\Inventory\StockTransferService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class InventoryPhase11Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('inv11', 'inv11@test.local');
    }

    public function test_phase11_inventory_tables_exist(): void
    {
        $tables = [
            'inventory_movements',
            'stock_balances',
            'batches',
            'serial_numbers',
            'stock_transfers',
            'stock_transfer_items',
            'stock_adjustments',
        ];

        foreach ($tables as $table) {
            $this->assertTrue(
                \Illuminate\Support\Facades\Schema::hasTable($table),
                "Missing table: {$table}",
            );
        }
    }

    public function test_movement_types_endpoint(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->getJson('/api/v1/inventory/movement-types', $headers)
            ->assertOk()
            ->assertJsonFragment(['value' => 'PURCHASE'])
            ->assertJsonFragment(['value' => 'INITIAL_STOCK'])
            ->assertJsonFragment(['value' => 'EXPIRED']);
    }

    public function test_initial_stock_creates_movement_and_balance(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 100,
            'unit_cost' => 500,
        ], $headers)->assertCreated()
            ->assertJsonPath('data.quantity', 100)
            ->assertJsonPath('data.movement_type', 'INITIAL_STOCK');

        $this->getJson("/api/v1/warehouses/{$warehouse->id}/stock", $headers)
            ->assertOk()
            ->assertJsonPath('data.data.0.quantity_on_hand', 100)
            ->assertJsonPath('data.data.0.quantity_available', 100);
    }

    public function test_stock_cannot_be_modified_directly(): void
    {
        $this->expectException(ValidationException::class);

        StockBalance::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'warehouse_id' => $this->fixture['warehouse']->id,
            'product_id' => $this->fixture['product']->id,
            'quantity_on_hand' => 50,
        ]);
    }

    public function test_inventory_movements_are_immutable(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $movement = $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
        ], $headers)->assertCreated()->json('data');

        $record = \App\Models\InventoryMovement::query()->findOrFail($movement['id']);

        $this->expectException(ValidationException::class);
        $record->update(['quantity' => 999]);
    }

    public function test_sale_decreases_stock_and_blocks_insufficient_quantity(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 20,
        ], $headers)->assertCreated();

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'SALE',
            'quantity' => 5,
        ], $headers)->assertCreated()
            ->assertJsonPath('data.quantity', -5);

        $this->getJson("/api/v1/warehouses/{$warehouse->id}/stock", $headers)
            ->assertOk()
            ->assertJsonPath('data.data.0.quantity_on_hand', 15);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'SALE',
            'quantity' => 100,
        ], $headers)->assertStatus(422);
    }

    public function test_stock_transfer_moves_quantity_between_warehouses(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $source = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $destination = Warehouse::create([
            'tenant_id' => $this->fixture['tenant']->id,
            'branch_id' => $this->fixture['branch']->id,
            'name' => 'Warehouse B',
            'code' => 'WH-B',
            'is_active' => true,
        ]);

        app(InventoryMovementService::class)->record([
            'warehouse' => $source,
            'product' => $product,
            'movement_type' => InventoryMovementType::InitialStock,
            'quantity' => 50,
        ]);

        $transfer = $this->postJson('/api/v1/stock-transfers', [
            'source_warehouse_id' => $source->id,
            'destination_warehouse_id' => $destination->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 10],
            ],
        ], $headers)->assertCreated()->json('data');

        $this->postJson("/api/v1/stock-transfers/{$transfer['id']}/confirm", [], $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'pending');
        $this->postJson("/api/v1/stock-transfers/{$transfer['id']}/approve", [], $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'approved');
        $this->postJson("/api/v1/stock-transfers/{$transfer['id']}/ship", [], $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'in_transit');
        $this->postJson("/api/v1/stock-transfers/{$transfer['id']}/receive", [], $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'completed');

        $this->getJson("/api/v1/warehouses/{$source->id}/stock", $headers)
            ->assertOk()
            ->assertJsonPath('data.data.0.quantity_on_hand', 40);

        $this->getJson("/api/v1/warehouses/{$destination->id}/stock", $headers)
            ->assertOk()
            ->assertJsonPath('data.data.0.quantity_on_hand', 10);
    }

    public function test_stock_adjustment_records_damage_movement(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        app(InventoryMovementService::class)->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::InitialStock,
            'quantity' => 30,
        ]);

        $this->postJson('/api/v1/stock-adjustments', [
            'warehouse_id' => $warehouse->id,
            'movement_type' => 'DAMAGE',
            'reason' => 'Broken packaging',
            'items' => [
                ['product_id' => $product->id, 'quantity' => 3],
            ],
        ], $headers)->assertCreated()
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.movement_type', 'DAMAGE');

        $this->getJson("/api/v1/warehouses/{$warehouse->id}/stock", $headers)
            ->assertOk()
            ->assertJsonPath('data.data.0.quantity_on_hand', 27);
    }

    public function test_batch_creation_and_tracking(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];

        $batch = $this->postJson("/api/v1/products/{$product->id}/batches", [
            'batch_number' => 'LOT-2026-001',
            'expires_at' => '2026-12-31',
        ], $headers)->assertCreated()->json('data');

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'batch_id' => $batch['id'],
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 25,
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/warehouses/{$warehouse->id}/stock?product_id={$product->id}", $headers)
            ->assertOk()
            ->assertJsonPath('data.data.0.batch_id', $batch['id'])
            ->assertJsonPath('data.data.0.quantity_on_hand', 25);
    }

    public function test_balance_reconciliation_matches_movements_sum(): void
    {
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $service = app(InventoryMovementService::class);
        $balanceService = app(\App\Services\Inventory\StockBalanceService::class);

        $service->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::InitialStock,
            'quantity' => 100,
        ]);

        $service->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::Sale,
            'quantity' => 15,
        ]);

        $service->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::SaleReturn,
            'quantity' => 5,
        ]);

        $reconciled = $balanceService->reconcile($warehouse, $product);

        $this->assertSame(90, $reconciled->quantity_on_hand);
    }
}
