<?php

namespace Tests\Feature\Inventory;

use App\Enums\BatchAllocationStrategy;
use App\Enums\InventoryAlertType;
use App\Enums\InventoryMovementType;
use App\Models\InventoryAlert;
use App\Models\Product;
use App\Services\Inventory\BatchAllocationService;
use App\Services\Inventory\BatchService;
use App\Services\Inventory\InventoryMovementService;
use App\Services\Inventory\StockAlertService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class InventoryPhase12Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('inv12', 'inv12@test.local');
    }

    public function test_phase12_tables_exist(): void
    {
        $this->assertTrue(Schema::hasTable('inventory_alerts'));
        $this->assertTrue(Schema::hasColumn('batches', 'unit_cost'));
        $this->assertTrue(Schema::hasColumn('products', 'low_stock_threshold'));
    }

    public function test_batch_receive_stores_cost_quantity_and_dates(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];

        $product = Product::query()->findOrFail($this->fixture['product']->id);
        $product->update(['track_batch' => true, 'track_expiration' => true]);

        $batch = $this->postJson("/api/v1/products/{$product->id}/batches", [
            'batch_number' => 'LOT-A-001',
            'manufactured_at' => '2026-01-15',
            'expires_at' => '2026-06-15',
            'unit_cost' => 450,
            'quantity' => 50,
            'warehouse_id' => $warehouse->id,
        ], $headers)->assertCreated()
            ->assertJsonPath('data.batch_number', 'LOT-A-001')
            ->assertJsonPath('data.unit_cost', 450)
            ->assertJsonPath('data.quantity_on_hand', 50)
            ->json('data');

        $this->getJson("/api/v1/batches/{$batch['id']}?warehouse_id={$warehouse->id}", $headers)
            ->assertOk()
            ->assertJsonPath('data.manufactured_at', '2026-01-15')
            ->assertJsonPath('data.expires_at', '2026-06-15');
    }

    public function test_fifo_allocates_oldest_batch_first(): void
    {
        $warehouse = $this->fixture['warehouse'];
        $product = Product::query()->findOrFail($this->fixture['product']->id);
        $product->update(['track_batch' => true, 'track_expiration' => false]);

        $batchService = app(BatchService::class);
        $movementService = app(InventoryMovementService::class);

        $batchService->receiveStock($warehouse, $product, [
            'batch_number' => 'FIFO-OLD',
            'quantity' => 10,
            'manufactured_at' => '2026-01-01',
            'unit_cost' => 100,
        ]);

        $batchService->receiveStock($warehouse, $product, [
            'batch_number' => 'FIFO-NEW',
            'quantity' => 10,
            'manufactured_at' => '2026-03-01',
            'unit_cost' => 120,
        ]);

        $preview = app(BatchAllocationService::class)->preview(
            warehouse: $warehouse,
            product: $product,
            quantity: 12,
            strategy: BatchAllocationStrategy::Fifo,
        );

        $this->assertSame('FIFO-OLD', $preview[0]['batch_number']);
        $this->assertSame(10, $preview[0]['quantity']);
        $this->assertSame('FIFO-NEW', $preview[1]['batch_number']);
        $this->assertSame(2, $preview[1]['quantity']);

        $movementService->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::Sale,
            'quantity' => 12,
            'allocation_strategy' => BatchAllocationStrategy::Fifo,
        ]);

        $this->assertSame(0, \App\Models\Batch::query()->where('batch_number', 'FIFO-OLD')->first()->quantityInWarehouse($warehouse));
        $this->assertSame(8, \App\Models\Batch::query()->where('batch_number', 'FIFO-NEW')->first()->quantityInWarehouse($warehouse));
    }

    public function test_fefo_allocates_earliest_expiry_first(): void
    {
        $warehouse = $this->fixture['warehouse'];
        $product = Product::query()->findOrFail($this->fixture['product']->id);
        $product->update(['track_batch' => true, 'track_expiration' => true]);

        $batchService = app(BatchService::class);

        $batchService->receiveStock($warehouse, $product, [
            'batch_number' => 'FEFO-LATE',
            'quantity' => 20,
            'expires_at' => '2027-06-01',
        ]);

        $batchService->receiveStock($warehouse, $product, [
            'batch_number' => 'FEFO-SOON',
            'quantity' => 20,
            'expires_at' => '2026-10-15',
        ]);

        $preview = app(BatchAllocationService::class)->preview(
            warehouse: $warehouse,
            product: $product->fresh(),
            quantity: 15,
            strategy: BatchAllocationStrategy::Fefo,
        );

        $this->assertSame('FEFO-SOON', $preview[0]['batch_number']);
        $this->assertSame(15, $preview[0]['quantity']);
    }

    public function test_blocks_outbound_from_expired_batch(): void
    {
        $warehouse = $this->fixture['warehouse'];
        $product = Product::query()->findOrFail($this->fixture['product']->id);
        $product->update(['track_batch' => true, 'track_expiration' => true]);

        $batch = app(BatchService::class)->receiveStock($warehouse, $product, [
            'batch_number' => 'EXP-BATCH',
            'quantity' => 5,
            'expires_at' => now()->subDay()->toDateString(),
        ]);

        $this->expectException(\Illuminate\Validation\ValidationException::class);

        app(InventoryMovementService::class)->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::Sale,
            'quantity' => 1,
            'batch_id' => $batch->id,
            'auto_allocate' => false,
        ]);
    }

    public function test_low_stock_alert_is_created(): void
    {
        Event::fake([\App\Events\StockLow::class]);

        $warehouse = $this->fixture['warehouse'];
        $product = Product::query()->findOrFail($this->fixture['product']->id);
        $product->update(['low_stock_threshold' => 10]);

        app(InventoryMovementService::class)->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::InitialStock,
            'quantity' => 8,
        ]);

        $alert = InventoryAlert::query()
            ->where('product_id', $product->id)
            ->where('alert_type', InventoryAlertType::LowStock)
            ->first();

        $this->assertNotNull($alert);
        $this->assertSame(8, $alert->quantity_on_hand);
        Event::assertDispatched(\App\Events\StockLow::class);
    }

    public function test_out_of_stock_alert_is_created(): void
    {
        $warehouse = $this->fixture['warehouse'];
        $product = Product::query()->findOrFail($this->fixture['product']->id);

        app(InventoryMovementService::class)->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::InitialStock,
            'quantity' => 5,
        ]);

        app(InventoryMovementService::class)->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::Sale,
            'quantity' => 5,
        ]);

        $this->assertTrue(
            InventoryAlert::query()
                ->where('product_id', $product->id)
                ->where('alert_type', InventoryAlertType::OutOfStock)
                ->where('status', 'active')
                ->exists()
        );
    }

    public function test_expiring_soon_and_expired_alerts(): void
    {
        $warehouse = $this->fixture['warehouse'];
        $product = Product::query()->findOrFail($this->fixture['product']->id);
        $product->update(['track_batch' => true, 'track_expiration' => true]);

        app(BatchService::class)->receiveStock($warehouse, $product, [
            'batch_number' => 'SOON-LOT',
            'quantity' => 10,
            'expires_at' => now()->addDays(7)->toDateString(),
        ]);

        app(BatchService::class)->receiveStock($warehouse, $product, [
            'batch_number' => 'DEAD-LOT',
            'quantity' => 5,
            'expires_at' => now()->subDays(3)->toDateString(),
        ]);

        app(StockAlertService::class)->evaluateWarehouse($warehouse);

        $this->assertTrue(
            InventoryAlert::query()->where('alert_type', InventoryAlertType::ExpiringSoon)->where('status', 'active')->exists()
        );
        $this->assertTrue(
            InventoryAlert::query()->where('alert_type', InventoryAlertType::Expired)->where('status', 'active')->exists()
        );
    }

    public function test_inventory_alerts_api(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $warehouse = $this->fixture['warehouse'];
        $product = Product::query()->findOrFail($this->fixture['product']->id);
        $product->update(['low_stock_threshold' => 20]);

        app(InventoryMovementService::class)->record([
            'warehouse' => $warehouse,
            'product' => $product,
            'movement_type' => InventoryMovementType::InitialStock,
            'quantity' => 5,
        ]);

        $this->getJson('/api/v1/inventory/alert-types', $headers)
            ->assertOk()
            ->assertJsonFragment(['value' => 'LOW_STOCK'])
            ->assertJsonFragment(['value' => 'EXPIRED']);

        $alert = $this->getJson('/api/v1/inventory/alerts', $headers)
            ->assertOk()
            ->json('data.data.0');

        $this->postJson("/api/v1/inventory/alerts/{$alert['id']}/acknowledge", [], $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'acknowledged');
    }
}
