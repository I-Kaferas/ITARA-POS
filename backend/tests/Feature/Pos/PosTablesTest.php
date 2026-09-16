<?php

namespace Tests\Feature\Pos;

use App\Enums\PosTableStatus;
use App\Enums\SaleStatus;
use App\Models\PosTable;
use App\Models\Role;
use App\Models\Sale;
use App\Models\SaleInvoice;
use App\Models\SaleReceipt;
use App\Models\StockBalance;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PosTablesTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('tables', 'tables@test.local');
        $this->fixture['product']->importToStore($this->fixture['store']);
    }

    public function test_create_update_and_deactivate_table(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];

        $zone = $this->postJson("/api/v1/stores/{$store->id}/pos/table-zones", [
            'name' => 'Salle',
        ], $headers)->assertCreated()->json('data');

        $created = $this->postJson("/api/v1/stores/{$store->id}/pos/tables", [
            'name' => 'Table 01',
            'code' => 'T01',
            'capacity' => 4,
            'zone_id' => $zone['id'],
            'description' => 'Près de la fenêtre',
        ], $headers)->assertCreated()->json('data');

        $this->assertSame('available', $created['status']);
        $this->assertSame(4, $created['capacity']);

        $updated = $this->putJson("/api/v1/pos-tables/{$created['id']}", [
            'name' => 'Table VIP',
            'capacity' => 10,
            'zone_id' => $zone['id'],
        ], $headers)->assertOk()->json('data');

        $this->assertSame('Table VIP', $updated['name']);
        $this->assertSame(10, $updated['capacity']);

        $this->deleteJson("/api/v1/pos-tables/{$created['id']}", [], $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'inactive')
            ->assertJsonPath('data.is_active', false);
    }

    public function test_open_order_add_products_pay_and_free_table(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $table = $this->makeTable('Table 02');

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 20,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $opened = $this->postJson("/api/v1/stores/{$store->id}/pos/tables/{$table->id}/open", [], $headers)
            ->assertCreated()
            ->json('data');

        $saleId = $opened['sale']['id'];
        $this->assertSame(SaleStatus::Pending->value, $opened['sale']['status']);
        $this->assertDatabaseHas('pos_tables', [
            'id' => $table->id,
            'status' => PosTableStatus::Occupied->value,
            'current_sale_id' => $saleId,
        ]);

        $this->putJson("/api/v1/sales/{$saleId}", [
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
        ], $headers)->assertOk()->assertJsonPath('data.total', 2000);

        $this->putJson("/api/v1/sales/{$saleId}", [
            'items' => [
                ['product_id' => $product->id, 'quantity' => 3],
            ],
        ], $headers)->assertOk()->assertJsonPath('data.total', 3000);

        $this->putJson("/api/v1/sales/{$saleId}", [
            'items' => [
                ['product_id' => $product->id, 'quantity' => 3],
                ['product_id' => $product->id, 'quantity' => 1],
            ],
        ], $headers)->assertOk();

        $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'sale_id' => $saleId,
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 4],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 4000],
            ],
        ], $headers)->assertCreated()->assertJsonPath('data.sale.status', 'completed');

        $this->assertDatabaseHas('pos_tables', [
            'id' => $table->id,
            'status' => PosTableStatus::Available->value,
            'current_sale_id' => null,
        ]);

        $this->assertDatabaseHas('sales', [
            'id' => $saleId,
            'table_id' => $table->id,
            'status' => SaleStatus::Completed->value,
        ]);

        $balance = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->first();
        $this->assertSame(16, $balance?->quantity_on_hand);

        $this->assertTrue(SaleReceipt::query()->where('sale_id', $saleId)->exists());
        $this->assertTrue(
            SaleInvoice::query()->where('sale_id', $saleId)->exists()
            || SaleReceipt::query()->where('sale_id', $saleId)->exists()
        );

        $this->getJson("/api/v1/pos-tables/{$table->id}/history", $headers)
            ->assertOk()
            ->assertJsonPath('data.0.id', $saleId);
    }

    public function test_hold_keeps_table_occupied(): void
    {
        $headers = $this->headers();
        $product = $this->fixture['product'];
        $table = $this->makeTable('Table Hold');

        $saleId = $this->postJson("/api/v1/stores/{$this->fixture['store']->id}/pos/tables/{$table->id}/open", [], $headers)
            ->json('data.sale.id');

        $this->putJson("/api/v1/sales/{$saleId}", [
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
        ], $headers)->assertOk();

        $table->refresh();
        $this->assertSame(PosTableStatus::Occupied, $table->status);
        $this->assertSame($saleId, $table->current_sale_id);
    }

    public function test_cancel_order_frees_table_and_keeps_history(): void
    {
        $headers = $this->headers();
        $table = $this->makeTable('Table Cancel');

        $saleId = $this->postJson("/api/v1/stores/{$this->fixture['store']->id}/pos/tables/{$table->id}/open", [], $headers)
            ->json('data.sale.id');

        $this->postJson("/api/v1/pos-tables/{$table->id}/cancel", [
            'reason' => 'Client parti',
        ], $headers)->assertOk();

        $this->assertDatabaseHas('pos_tables', [
            'id' => $table->id,
            'status' => PosTableStatus::Available->value,
            'current_sale_id' => null,
        ]);
        $this->assertDatabaseHas('sales', [
            'id' => $saleId,
            'status' => SaleStatus::Voided->value,
            'table_id' => $table->id,
        ]);
    }

    public function test_transfer_and_merge_orders(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];
        $product = $this->fixture['product'];
        $one = $this->makeTable('Table A');
        $two = $this->makeTable('Table B');
        $three = $this->makeTable('Table C');

        $saleA = $this->postJson("/api/v1/stores/{$store->id}/pos/tables/{$one->id}/open", [], $headers)->json('data.sale.id');
        $this->putJson("/api/v1/sales/{$saleA}", [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
        ], $headers)->assertOk();

        $this->postJson("/api/v1/pos-tables/{$one->id}/transfer", [
            'to_table_id' => $two->id,
        ], $headers)->assertOk();

        $this->assertDatabaseHas('pos_tables', ['id' => $one->id, 'status' => 'available', 'current_sale_id' => null]);
        $this->assertDatabaseHas('pos_tables', ['id' => $two->id, 'status' => 'occupied', 'current_sale_id' => $saleA]);
        $this->assertDatabaseHas('sales', ['id' => $saleA, 'table_id' => $two->id]);

        $saleC = $this->postJson("/api/v1/stores/{$store->id}/pos/tables/{$three->id}/open", [], $headers)->json('data.sale.id');
        $this->putJson("/api/v1/sales/{$saleC}", [
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
        ], $headers)->assertOk();

        $merged = $this->postJson("/api/v1/pos-tables/{$three->id}/merge", [
            'to_table_id' => $two->id,
        ], $headers)->assertOk()->json('data');

        $this->assertSame($saleA, $merged['sale']['id']);
        $this->assertGreaterThan(2000, $merged['sale']['total']);
        $this->assertDatabaseHas('sales', [
            'id' => $saleC,
            'status' => SaleStatus::Merged->value,
            'merged_into_id' => $saleA,
        ]);
        $this->assertDatabaseHas('pos_tables', ['id' => $three->id, 'status' => 'available']);
        $this->assertDatabaseHas('pos_tables', ['id' => $two->id, 'status' => 'occupied']);
    }

    public function test_reserve_requires_confirmation_to_open(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];
        $table = $this->makeTable('Table 05');

        $this->postJson("/api/v1/stores/{$store->id}/pos/tables/{$table->id}/reserve", [
            'guest_name' => 'Jean Dupont',
            'party_size' => 6,
            'reserved_at' => now()->addHour()->toIso8601String(),
        ], $headers)->assertCreated();

        $this->assertDatabaseHas('pos_tables', [
            'id' => $table->id,
            'status' => PosTableStatus::Reserved->value,
        ]);

        $this->postJson("/api/v1/stores/{$store->id}/pos/tables/{$table->id}/open", [], $headers)
            ->assertUnprocessable();

        $this->postJson("/api/v1/stores/{$store->id}/pos/tables/{$table->id}/open", [
            'confirm_reserved' => true,
        ], $headers)->assertCreated();

        $this->assertDatabaseHas('pos_tables', [
            'id' => $table->id,
            'status' => PosTableStatus::Occupied->value,
        ]);
    }

    public function test_cannot_open_two_inconsistent_orders_on_same_table(): void
    {
        $headers = $this->headers();
        $store = $this->fixture['store'];
        $table = $this->makeTable('Table Race');

        $first = $this->postJson("/api/v1/stores/{$store->id}/pos/tables/{$table->id}/open", [], $headers)
            ->assertCreated()
            ->json('data.sale.id');

        $second = $this->postJson("/api/v1/stores/{$store->id}/pos/tables/{$table->id}/open", [], $headers)
            ->assertCreated()
            ->json('data.sale.id');

        $this->assertSame($first, $second);
        $this->assertSame(1, Sale::query()->where('table_id', $table->id)->where('status', 'pending')->count());
    }

    public function test_cashier_cannot_manage_tables(): void
    {
        $store = $this->fixture['store'];
        $cashierRole = Role::query()
            ->where('tenant_id', $this->fixture['tenant']->id)
            ->where('slug', 'cashier')
            ->firstOrFail();

        $cashier = User::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'name' => 'Cashier',
            'email' => 'cashier-tables@test.local',
            'password' => Hash::make('password'),
            'is_active' => true,
            'email_verified_at' => now(),
        ]);
        $cashier->roles()->attach($cashierRole->id, ['branch_id' => null, 'store_id' => null]);
        $token = app(\App\Services\Auth\AuthTokenService::class)->issue($cashier)['access_token'];
        $headers = $this->tenantHeaders($token, $this->fixture['tenant']);

        $this->getJson("/api/v1/stores/{$store->id}/pos/tables", $headers)->assertOk();

        $this->postJson("/api/v1/stores/{$store->id}/pos/tables", [
            'name' => 'Table X',
            'capacity' => 2,
        ], $headers)->assertForbidden();
    }

    /** @return array<string, string> */
    private function headers(): array
    {
        return $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
    }

    private function makeTable(string $name): PosTable
    {
        $store = $this->fixture['store'];
        $payload = $this->postJson("/api/v1/stores/{$store->id}/pos/tables", [
            'name' => $name,
            'capacity' => 4,
        ], $this->headers())->assertCreated()->json('data');

        return PosTable::query()->findOrFail($payload['id']);
    }
}
