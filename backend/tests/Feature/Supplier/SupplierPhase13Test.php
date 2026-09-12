<?php

namespace Tests\Feature\Supplier;

use App\Models\Purchase;
use App\Models\Supplier;
use App\Models\SupplierTransaction;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class SupplierPhase13Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('sup13', 'sup13@test.local');
    }

    public function test_phase13_supplier_tables_exist(): void
    {
        $this->assertTrue(Schema::hasTable('suppliers'));
        $this->assertTrue(Schema::hasTable('supplier_contacts'));
        $this->assertTrue(Schema::hasTable('supplier_transactions'));
        $this->assertTrue(Schema::hasTable('supplier_payments'));
        $this->assertTrue(Schema::hasColumn('suppliers', 'payment_terms_days'));
        $this->assertTrue(Schema::hasColumn('purchase_orders', 'due_date'));
    }

    public function test_supplier_crud_and_contacts(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $supplier = $this->postJson('/api/v1/suppliers', [
            'name' => 'Fournisseur ABC',
            'code' => 'SUP-ABC',
            'legal_name' => 'ABC SARL',
            'payment_terms_days' => 45,
            'credit_limit' => 500000,
        ], $headers)->assertCreated()
            ->assertJsonPath('data.name', 'Fournisseur ABC')
            ->json('data');

        $this->postJson("/api/v1/suppliers/{$supplier['id']}/contacts", [
            'name' => 'Jean Dupont',
            'title' => 'Commercial',
            'email' => 'jean@abc.com',
            'is_primary' => true,
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/suppliers/{$supplier['id']}", $headers)
            ->assertOk()
            ->assertJsonPath('summary.debt', 0)
            ->assertJsonCount(1, 'data.contacts');
    }

    public function test_purchase_transaction_creates_debt(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];

        $this->postJson("/api/v1/suppliers/{$supplier->id}/transactions", [
            'transaction_type' => 'PURCHASE',
            'amount' => 150000,
            'reference' => 'FAC-2026-001',
            'due_date' => '2026-10-15',
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/suppliers/{$supplier->id}/summary", $headers)
            ->assertOk()
            ->assertJsonPath('data.debt', 150000)
            ->assertJsonPath('data.balance', 150000);
    }

    public function test_payment_reduces_debt_and_allocates_to_invoice(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];
        $ledger = app(SupplierLedgerService::class);

        $invoice = $ledger->recordPayable($supplier, [
            'transaction_type' => \App\Enums\SupplierTransactionType::Purchase,
            'amount' => 100000,
            'reference' => 'FAC-100',
            'due_date' => now()->addDays(30)->toDateString(),
        ]);

        $this->postJson("/api/v1/suppliers/{$supplier->id}/payments", [
            'amount' => 60000,
            'payment_method' => 'bank_transfer',
            'allocations' => [
                ['transaction_id' => $invoice->id, 'amount' => 60000],
            ],
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/suppliers/{$supplier->id}/summary", $headers)
            ->assertOk()
            ->assertJsonPath('data.debt', 40000)
            ->assertJsonPath('data.total_payments', 60000);

        $invoice->refresh();
        $this->assertSame(60000, $invoice->paid_amount);
        $this->assertSame(40000, $invoice->outstandingAmount());
    }

    public function test_credit_note_creates_supplier_credit(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];

        app(SupplierLedgerService::class)->recordPayable($supplier, [
            'transaction_type' => \App\Enums\SupplierTransactionType::Purchase,
            'amount' => 50000,
            'reference' => 'FAC-200',
        ]);

        $this->postJson("/api/v1/suppliers/{$supplier->id}/credit-notes", [
            'amount' => 80000,
            'reference' => 'AV-001',
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/suppliers/{$supplier->id}/summary", $headers)
            ->assertOk()
            ->assertJsonPath('data.credit', 30000)
            ->assertJsonPath('data.balance', -30000);
    }

    public function test_statement_and_due_dates(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];
        $ledger = app(SupplierLedgerService::class);

        $ledger->recordPayable($supplier, [
            'transaction_type' => \App\Enums\SupplierTransactionType::Purchase,
            'amount' => 75000,
            'reference' => 'FAC-DUE',
            'due_date' => now()->subDays(5)->toDateString(),
        ]);

        $this->getJson("/api/v1/suppliers/{$supplier->id}/statement", $headers)
            ->assertOk()
            ->assertJsonPath('meta.debt', 75000)
            ->assertJsonCount(1, 'data');

        $this->getJson("/api/v1/suppliers/{$supplier->id}/due-dates", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data.open')
            ->assertJsonCount(1, 'data.overdue');
    }

    public function test_purchase_history_links_to_supplier(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];

        $purchase = Purchase::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'supplier_id' => $supplier->id,
            'warehouse_id' => $this->fixture['warehouse']->id,
            'order_number' => 'PO-2026-001',
            'reference' => 'PO-2026-001',
            'status' => 'received',
            'subtotal' => 250000,
            'total' => 250000,
            'due_date' => now()->addDays(30),
        ]);

        app(SupplierLedgerService::class)->recordPurchase($supplier, $purchase);

        $this->getJson("/api/v1/suppliers/{$supplier->id}/purchases", $headers)
            ->assertOk()
            ->assertJsonPath('data.0.reference', 'PO-2026-001')
            ->assertJsonCount(1, 'data.0.transactions');

        $this->assertSame(1, SupplierTransaction::query()->where('purchase_order_id', $purchase->id)->count());
    }

    public function test_supplier_transactions_are_immutable(): void
    {
        $supplier = $this->fixture['supplier'];
        $tx = app(SupplierLedgerService::class)->recordPayable($supplier, [
            'transaction_type' => \App\Enums\SupplierTransactionType::Purchase,
            'amount' => 1000,
            'reference' => 'X',
        ]);

        $this->expectException(\Illuminate\Validation\ValidationException::class);
        $tx->update(['amount' => 9999]);
    }
}
