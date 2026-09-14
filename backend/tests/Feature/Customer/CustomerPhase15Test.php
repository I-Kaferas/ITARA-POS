<?php

namespace Tests\Feature\Customer;

use App\Models\Customer;
use App\Models\Sale;
use App\Services\Customer\CustomerLedgerService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class CustomerPhase15Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('cust15', 'cust15@test.local');
    }

    public function test_phase15_customer_tables_exist(): void
    {
        $this->assertTrue(Schema::hasTable('customers'));
        $this->assertTrue(Schema::hasTable('customer_addresses'));
        $this->assertTrue(Schema::hasTable('customer_transactions'));
        $this->assertTrue(Schema::hasTable('customer_payments'));
        $this->assertTrue(Schema::hasColumn('customers', 'loyalty_points'));
        $this->assertTrue(Schema::hasColumn('customers', 'credit_limit'));
    }

    public function test_customer_profile_with_address(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $customer = $this->postJson('/api/v1/customers', [
            'name' => 'Alice Martin',
            'code' => 'CLI-001',
            'email' => 'alice@test.local',
            'credit_limit' => 200000,
            'payment_terms_days' => 15,
        ], $headers)->assertCreated()->json('data');

        $this->postJson("/api/v1/customers/{$customer['id']}/addresses", [
            'line1' => '12 Avenue de la Paix',
            'city' => 'Bujumbura',
            'country_code' => 'BI',
            'is_primary' => true,
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/customers/{$customer['id']}", $headers)
            ->assertOk()
            ->assertJsonPath('summary.receivable', 0)
            ->assertJsonPath('loyalty.points', 0)
            ->assertJsonCount(1, 'data.addresses');
    }

    public function test_sale_creates_receivable_and_loyalty_points(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $customer = $this->fixture['customer'];

        $this->postJson("/api/v1/customers/{$customer->id}/transactions", [
            'transaction_type' => 'SALE',
            'amount' => 100000,
            'reference' => 'INV-001',
            'due_date' => now()->addDays(15)->toDateString(),
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/customers/{$customer->id}/summary", $headers)
            ->assertOk()
            ->assertJsonPath('data.receivable', 100000)
            ->assertJsonPath('data.loyalty_points', 1);

        $this->getJson("/api/v1/customers/{$customer->id}/balance", $headers)
            ->assertOk()
            ->assertJsonPath('data.balance', 100000);
    }

    public function test_payment_reduces_balance(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $customer = $this->fixture['customer'];
        $ledger = app(CustomerLedgerService::class);

        $invoice = $ledger->recordReceivable($customer, [
            'transaction_type' => \App\Enums\CustomerTransactionType::Sale,
            'amount' => 50000,
            'reference' => 'INV-100',
            'due_date' => now()->addDays(10)->toDateString(),
            'earn_loyalty' => false,
        ]);

        $this->postJson("/api/v1/customers/{$customer->id}/payments", [
            'amount' => 30000,
            'payment_method' => 'cash',
            'allocations' => [
                ['transaction_id' => $invoice->id, 'amount' => 30000],
            ],
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/customers/{$customer->id}/summary", $headers)
            ->assertOk()
            ->assertJsonPath('data.receivable', 20000)
            ->assertJsonPath('data.total_payments', 30000);
    }

    public function test_credit_note_creates_customer_credit(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $customer = $this->fixture['customer'];

        app(CustomerLedgerService::class)->recordReceivable($customer, [
            'transaction_type' => \App\Enums\CustomerTransactionType::Sale,
            'amount' => 20000,
            'earn_loyalty' => false,
        ]);

        $this->postJson("/api/v1/customers/{$customer->id}/credit-notes", [
            'amount' => 25000,
            'reference' => 'CN-01',
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/customers/{$customer->id}/balance", $headers)
            ->assertOk()
            ->assertJsonPath('data.credit', 5000)
            ->assertJsonPath('data.balance', -5000);
    }

    public function test_credit_limit_blocks_excessive_sale(): void
    {
        $customer = $this->fixture['customer'];
        $customer->update(['credit_limit' => 10000]);

        $this->expectException(\Illuminate\Validation\ValidationException::class);

        app(CustomerLedgerService::class)->recordReceivable($customer, [
            'transaction_type' => \App\Enums\CustomerTransactionType::Sale,
            'amount' => 15000,
            'earn_loyalty' => false,
        ]);
    }

    public function test_history_and_loyalty_redeem(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $customer = $this->fixture['customer'];
        $customer->update(['loyalty_points' => 600]);

        $this->postJson("/api/v1/customers/{$customer->id}/transactions", [
            'transaction_type' => 'SALE',
            'amount' => 5000,
            'reference' => 'INV-HIST',
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/customers/{$customer->id}/history", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->postJson("/api/v1/customers/{$customer->id}/loyalty/redeem", [
            'points' => 100,
        ], $headers)->assertOk()
            ->assertJsonPath('data.points', 500);

        $customer->refresh();
        $this->assertSame(500, $customer->loyalty_points);
    }

    public function test_sale_history_links_to_customer(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $customer = $this->fixture['customer'];

        $sale = Sale::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'store_id' => $this->fixture['store']->id,
            'customer_id' => $customer->id,
            'reference' => 'SALE-001',
            'status' => 'completed',
            'total' => 35000,
        ]);

        app(CustomerLedgerService::class)->recordSale($customer, $sale);

        $this->getJson("/api/v1/customers/{$customer->id}/sales", $headers)
            ->assertOk()
            ->assertJsonPath('data.0.reference', 'SALE-001')
            ->assertJsonCount(1, 'data.0.transactions');
    }

    public function test_customer_transactions_are_immutable(): void
    {
        $customer = $this->fixture['customer'];
        $tx = app(CustomerLedgerService::class)->recordReceivable($customer, [
            'transaction_type' => \App\Enums\CustomerTransactionType::Sale,
            'amount' => 1000,
            'earn_loyalty' => false,
        ]);

        $this->expectException(\Illuminate\Validation\ValidationException::class);
        $tx->update(['amount' => 9999]);
    }
}
