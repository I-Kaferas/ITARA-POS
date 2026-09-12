<?php



namespace Tests\Feature\Sales;



use App\Enums\CashMovementType;

use App\Models\CashMovement;

use App\Models\CustomerTransaction;

use App\Models\PaymentTransaction;

use App\Models\SaleRefund;

use Illuminate\Foundation\Testing\RefreshDatabase;

use Illuminate\Support\Facades\Schema;

use Tests\Support\InteractsWithTenants;

use Tests\TestCase;



class SalesPhase28Test extends TestCase

{

    use InteractsWithTenants;

    use RefreshDatabase;



    private array $fixture;



    protected function setUp(): void

    {

        parent::setUp();

        $this->fixture = $this->createTenantFixture('sales28', 'sales28@test.local');

    }



    public function test_phase28_refund_tables_exist(): void

    {

        $this->assertTrue(Schema::hasTable('sale_refunds'));

        $this->assertTrue(Schema::hasColumn('payment_transactions', 'transaction_type'));

        $this->assertTrue(Schema::hasColumn('payment_transactions', 'sale_return_id'));

        $this->assertTrue(Schema::hasColumn('payment_transactions', 'original_transaction_id'));

    }



    public function test_refund_methods_endpoint(): void

    {

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);



        $response = $this->getJson('/api/v1/refunds/methods', $headers)->assertOk();



        $methods = collect($response->json('data'))->pluck('value')->all();



        $this->assertContains('cash', $methods);

        $this->assertContains('card', $methods);

        $this->assertContains('mobile_money', $methods);

        $this->assertContains('wallet', $methods);

        $this->assertContains('credit', $methods);

        $this->assertContains('none', $methods);

    }



    public function test_cash_refund_records_movement_and_audit_log(): void

    {

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $store = $this->fixture['store'];

        $warehouse = $this->fixture['warehouse'];

        $product = $this->fixture['product'];



        $product->importToStore($store);



        $registerId = $this->postJson("/api/v1/stores/{$store->id}/cash-registers", [

            'name' => 'Caisse remboursement',

            'code' => 'REG-RFD',

        ], $headers)->json('data.id');



        $this->postJson("/api/v1/cash-registers/{$registerId}/sessions/open", [

            'opening_balance' => 10000,

        ], $headers)->assertCreated();



        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [

            'product_id' => $product->id,

            'movement_type' => 'INITIAL_STOCK',

            'quantity' => 20,

            'unit_cost' => 500,

        ], $headers);



        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [

            'warehouse_id' => $warehouse->id,

            'cash_register_id' => $registerId,

            'items' => [

                ['product_id' => $product->id, 'quantity' => 2],

            ],

            'payments' => [

                ['method' => 'cash', 'amount' => 2000],

            ],

        ], $headers)->assertCreated();



        $saleId = $saleResponse->json('data.sale.id');

        $saleItemId = $saleResponse->json('data.sale.items.0.id');



        $response = $this->postJson("/api/v1/sales/{$saleId}/returns", [

            'reason' => 'defective',

            'refund_method' => 'cash',

            'cash_register_id' => $registerId,

            'items' => [

                ['sale_item_id' => $saleItemId, 'quantity' => 1],

            ],

        ], $headers)->assertCreated();



        $response->assertJsonPath('data.sale_return.refund_method', 'cash');

        $response->assertJsonPath('data.sale_return.refunds.0.refund_method', 'cash');

        $response->assertJsonPath('data.sale_return.refunds.0.amount', 1000);



        $refundId = $response->json('data.sale_return.refunds.0.id');



        $this->assertDatabaseHas('sale_refunds', [

            'id' => $refundId,

            'refund_method' => 'cash',

            'amount' => 1000,

        ]);



        $this->assertDatabaseHas('payment_transactions', [

            'sale_id' => $saleId,

            'transaction_type' => 'refund',

            'payment_method' => 'cash',

            'amount' => 1000,

        ]);



        $this->assertTrue(

            CashMovement::query()

                ->where('movement_type', CashMovementType::Refund)

                ->where('amount', 1000)

                ->exists()

        );



        $this->assertDatabaseHas('audit_logs', [

            'action' => 'sale_refund.processed',

            'entity_id' => $refundId,

        ]);

    }



    public function test_card_refund_creates_payment_reversal(): void

    {

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $store = $this->fixture['store'];

        $warehouse = $this->fixture['warehouse'];

        $product = $this->fixture['product'];



        $product->importToStore($store);



        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [

            'product_id' => $product->id,

            'movement_type' => 'INITIAL_STOCK',

            'quantity' => 10,

            'unit_cost' => 500,

        ], $headers);



        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [

            'warehouse_id' => $warehouse->id,

            'items' => [

                ['product_id' => $product->id, 'quantity' => 2],

            ],

            'payments' => [

                ['method' => 'card', 'amount' => 2000, 'metadata' => ['last_four' => '4242']],

            ],

        ], $headers)->assertCreated();



        $saleId = $saleResponse->json('data.sale.id');

        $saleItemId = $saleResponse->json('data.sale.items.0.id');

        $originalPaymentId = PaymentTransaction::query()

            ->where('sale_id', $saleId)

            ->where('transaction_type', 'payment')

            ->value('id');



        $this->postJson("/api/v1/sales/{$saleId}/returns", [

            'reason' => 'customer_changed_mind',

            'refund_method' => 'card',

            'items' => [

                ['sale_item_id' => $saleItemId, 'quantity' => 1],

            ],

        ], $headers)->assertCreated();



        $this->assertDatabaseHas('sale_refunds', [

            'sale_id' => $saleId,

            'refund_method' => 'card',

            'original_payment_transaction_id' => $originalPaymentId,

        ]);



        $this->assertDatabaseHas('payment_transactions', [

            'sale_id' => $saleId,

            'transaction_type' => 'refund',

            'payment_method' => 'card',

            'original_transaction_id' => $originalPaymentId,

        ]);

    }



    public function test_mobile_money_refund_creates_payment_reversal(): void

    {

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $store = $this->fixture['store'];

        $warehouse = $this->fixture['warehouse'];

        $product = $this->fixture['product'];



        $product->importToStore($store);



        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [

            'product_id' => $product->id,

            'movement_type' => 'INITIAL_STOCK',

            'quantity' => 10,

            'unit_cost' => 500,

        ], $headers);



        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [

            'warehouse_id' => $warehouse->id,

            'items' => [

                ['product_id' => $product->id, 'quantity' => 1],

            ],

            'payments' => [

                ['method' => 'mobile_money', 'amount' => 1000, 'metadata' => ['phone' => '+25760000001']],

            ],

        ], $headers)->assertCreated();



        $saleId = $saleResponse->json('data.sale.id');

        $saleItemId = $saleResponse->json('data.sale.items.0.id');



        $this->postJson("/api/v1/sales/{$saleId}/returns", [

            'reason' => 'wrong_item',

            'refund_method' => 'mobile_money',

            'items' => [

                ['sale_item_id' => $saleItemId, 'quantity' => 1],

            ],

        ], $headers)->assertCreated();



        $this->assertDatabaseHas('sale_refunds', [

            'sale_id' => $saleId,

            'refund_method' => 'mobile_money',

            'amount' => 1000,

        ]);

    }



    public function test_wallet_refund_credits_customer_balance(): void

    {

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $store = $this->fixture['store'];

        $warehouse = $this->fixture['warehouse'];

        $product = $this->fixture['product'];

        $customer = $this->fixture['customer'];



        $product->importToStore($store);



        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [

            'product_id' => $product->id,

            'movement_type' => 'INITIAL_STOCK',

            'quantity' => 10,

            'unit_cost' => 500,

        ], $headers);



        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [

            'warehouse_id' => $warehouse->id,

            'customer_id' => $customer->id,

            'items' => [

                ['product_id' => $product->id, 'quantity' => 2],

            ],

            'payments' => [

                ['method' => 'cash', 'amount' => 2000],

            ],

        ], $headers)->assertCreated();



        $saleId = $saleResponse->json('data.sale.id');

        $saleItemId = $saleResponse->json('data.sale.items.0.id');



        $this->postJson("/api/v1/sales/{$saleId}/returns", [

            'reason' => 'defective',

            'refund_method' => 'wallet',

            'items' => [

                ['sale_item_id' => $saleItemId, 'quantity' => 1],

            ],

        ], $headers)->assertCreated();



        $this->assertDatabaseHas('customer_transactions', [

            'customer_id' => $customer->id,

            'sale_id' => $saleId,

            'transaction_type' => 'CREDIT_NOTE',

            'amount' => 1000,

        ]);



        $this->assertDatabaseHas('sale_refunds', [

            'sale_id' => $saleId,

            'refund_method' => 'wallet',

        ]);

    }



    public function test_store_credit_refund_updates_customer_ledger(): void

    {

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $store = $this->fixture['store'];

        $warehouse = $this->fixture['warehouse'];

        $product = $this->fixture['product'];

        $customer = $this->fixture['customer'];



        $product->importToStore($store);



        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [

            'product_id' => $product->id,

            'movement_type' => 'INITIAL_STOCK',

            'quantity' => 20,

            'unit_cost' => 500,

        ], $headers);



        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [

            'warehouse_id' => $warehouse->id,

            'customer_id' => $customer->id,

            'items' => [

                ['product_id' => $product->id, 'quantity' => 2],

            ],

            'payments' => [

                ['method' => 'cash', 'amount' => 2000],

            ],

        ], $headers)->assertCreated();



        $saleId = $saleResponse->json('data.sale.id');

        $saleItemId = $saleResponse->json('data.sale.items.0.id');



        $this->postJson("/api/v1/sales/{$saleId}/returns", [

            'reason' => 'defective',

            'refund_method' => 'credit',

            'items' => [

                ['sale_item_id' => $saleItemId, 'quantity' => 1],

            ],

        ], $headers)->assertCreated();



        $this->assertDatabaseHas('customer_transactions', [

            'customer_id' => $customer->id,

            'sale_id' => $saleId,

            'transaction_type' => 'SALE_RETURN',

            'amount' => 1000,

        ]);



        $this->assertDatabaseHas('sale_refunds', [

            'sale_id' => $saleId,

            'refund_method' => 'credit',

        ]);

    }



    public function test_can_view_sale_refund_details(): void

    {

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $store = $this->fixture['store'];

        $warehouse = $this->fixture['warehouse'];

        $product = $this->fixture['product'];



        $product->importToStore($store);



        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [

            'product_id' => $product->id,

            'movement_type' => 'INITIAL_STOCK',

            'quantity' => 10,

            'unit_cost' => 500,

        ], $headers);



        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [

            'warehouse_id' => $warehouse->id,

            'items' => [

                ['product_id' => $product->id, 'quantity' => 1],

            ],

            'payments' => [

                ['method' => 'card', 'amount' => 1000],

            ],

        ], $headers)->assertCreated();



        $saleId = $saleResponse->json('data.sale.id');

        $saleItemId = $saleResponse->json('data.sale.items.0.id');



        $returnResponse = $this->postJson("/api/v1/sales/{$saleId}/returns", [

            'reason' => 'other',

            'refund_method' => 'card',

            'items' => [

                ['sale_item_id' => $saleItemId, 'quantity' => 1],

            ],

        ], $headers)->assertCreated();



        $refundId = $returnResponse->json('data.sale_return.refunds.0.id');



        $this->getJson("/api/v1/sale-refunds/{$refundId}", $headers)

            ->assertOk()

            ->assertJsonPath('data.id', $refundId)

            ->assertJsonPath('data.refund_method', 'card')

            ->assertJsonStructure([

                'data' => [

                    'id',

                    'refund_number',

                    'payment_transaction',

                    'original_payment_transaction',

                ],

            ]);

    }



    public function test_cash_refund_requires_open_register_session(): void

    {

        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $store = $this->fixture['store'];

        $warehouse = $this->fixture['warehouse'];

        $product = $this->fixture['product'];



        $product->importToStore($store);



        $registerId = $this->postJson("/api/v1/stores/{$store->id}/cash-registers", [

            'name' => 'Caisse fermée',

            'code' => 'REG-CLOSED',

        ], $headers)->json('data.id');



        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [

            'product_id' => $product->id,

            'movement_type' => 'INITIAL_STOCK',

            'quantity' => 10,

            'unit_cost' => 500,

        ], $headers);



        $saleResponse = $this->postJson("/api/v1/stores/{$store->id}/sales", [

            'warehouse_id' => $warehouse->id,

            'items' => [

                ['product_id' => $product->id, 'quantity' => 1],

            ],

            'payments' => [

                ['method' => 'cash', 'amount' => 1000],

            ],

        ], $headers)->assertCreated();



        $saleId = $saleResponse->json('data.sale.id');

        $saleItemId = $saleResponse->json('data.sale.items.0.id');



        $this->postJson("/api/v1/sales/{$saleId}/returns", [

            'reason' => 'other',

            'refund_method' => 'cash',

            'cash_register_id' => $registerId,

            'items' => [

                ['sale_item_id' => $saleItemId, 'quantity' => 1],

            ],

        ], $headers)->assertUnprocessable()

            ->assertJsonValidationErrors(['cash_register_id']);



        $this->assertDatabaseCount('sale_refunds', 0);

    }

}

