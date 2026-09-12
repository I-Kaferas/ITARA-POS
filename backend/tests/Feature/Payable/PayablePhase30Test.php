<?php

namespace Tests\Feature\Payable;

use App\Enums\SupplierTransactionType;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PayablePhase30Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('pay30', 'pay30@test.local');
    }

    public function test_phase30_payables_summary_endpoint(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];
        $ledger = app(SupplierLedgerService::class);

        $ledger->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => 120000,
            'reference' => 'FAC-AP-001',
            'due_date' => now()->addDays(30)->toDateString(),
        ]);

        $ledger->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => 50000,
            'reference' => 'FAC-AP-002',
            'due_date' => now()->subDays(10)->toDateString(),
        ]);

        $this->getJson('/api/v1/payables/summary', $headers)
            ->assertOk()
            ->assertJsonPath('data.total_debt', 170000)
            ->assertJsonPath('data.total_overdue', 50000)
            ->assertJsonPath('data.open_invoices', 2)
            ->assertJsonPath('data.overdue_invoices', 1)
            ->assertJsonPath('data.suppliers_with_debt', 1)
            ->assertJsonCount(1, 'data.suppliers');
    }

    public function test_phase30_payment_schedule_endpoint(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];
        $ledger = app(SupplierLedgerService::class);

        $ledger->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => 80000,
            'reference' => 'FAC-SCH-001',
            'due_date' => now()->addDays(15)->toDateString(),
        ]);

        $this->getJson('/api/v1/payables/schedule', $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.outstanding', 80000)
            ->assertJsonPath('data.0.supplier_name', $supplier->name);

        $this->getJson('/api/v1/payables/schedule?overdue_only=1', $headers)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_phase30_supplier_payment_reduces_outstanding_balance(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];
        $ledger = app(SupplierLedgerService::class);

        $invoice = $ledger->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => 100000,
            'reference' => 'FAC-PAY-001',
            'due_date' => now()->addDays(30)->toDateString(),
        ]);

        $this->postJson("/api/v1/suppliers/{$supplier->id}/payments", [
            'amount' => 40000,
            'payment_method' => 'bank_transfer',
            'allocations' => [
                ['transaction_id' => $invoice->id, 'amount' => 40000],
            ],
        ], $headers)->assertCreated();

        $this->getJson('/api/v1/payables/summary', $headers)
            ->assertOk()
            ->assertJsonPath('data.total_debt', 60000);

        $this->getJson('/api/v1/payables/schedule', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.outstanding', 60000);

        $this->getJson('/api/v1/payables/payments', $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.amount', 40000);
    }

    public function test_phase30_supplier_due_dates_shows_outstanding_balance(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $supplier = $this->fixture['supplier'];
        $ledger = app(SupplierLedgerService::class);

        $ledger->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => 75000,
            'reference' => 'FAC-DUE-001',
            'due_date' => now()->subDays(3)->toDateString(),
        ]);

        $this->getJson("/api/v1/suppliers/{$supplier->id}/due-dates", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data.open')
            ->assertJsonCount(1, 'data.overdue')
            ->assertJsonPath('data.open.0.outstanding', 75000);
    }
}
