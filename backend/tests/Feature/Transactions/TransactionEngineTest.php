<?php

namespace Tests\Feature\Transactions;

use App\Enums\TransactionPaymentStatus;
use App\Enums\TransactionStatus;
use App\Enums\TransactionType;
use App\Models\Transaction;
use App\Services\Transactions\TransactionEngine;
use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class TransactionEngineTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_transactions_table_has_required_columns(): void
    {
        $this->assertTrue(Schema::hasTable('transactions'));

        foreach ([
            'id',
            'reference',
            'idempotency_key',
            'tenant_id',
            'branch_id',
            'user_id',
            'type',
            'date',
            'status',
            'amount',
            'currency',
            'payment_status',
            'created_at',
            'updated_at',
        ] as $column) {
            $this->assertTrue(Schema::hasColumn('transactions', $column), "Missing column: {$column}");
        }
    }

    public function test_engine_records_all_transaction_types(): void
    {
        $fixture = $this->createTenantFixture('txn-engine', 'txn-engine@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $engine = app(TransactionEngine::class);

        foreach (TransactionType::cases() as $type) {
            $tx = $engine->recordFromArray([
                'tenant_id' => $fixture['tenant']->id,
                'branch_id' => $fixture['branch']->id,
                'user_id' => $fixture['user']->id,
                'type' => $type->value,
                'amount' => 1500,
                'currency' => 'FBU',
                'date' => '2026-10-07',
                'status' => TransactionStatus::Completed->value,
                'payment_status' => $type->defaultPaymentStatus()->value,
            ]);

            $this->assertInstanceOf(Transaction::class, $tx);
            $this->assertNotEmpty($tx->id);
            $this->assertNotEmpty($tx->reference);
            $this->assertSame($fixture['tenant']->id, $tx->tenant_id);
            $this->assertSame($fixture['branch']->id, $tx->branch_id);
            $this->assertSame($fixture['user']->id, $tx->user_id);
            $this->assertSame($type, $tx->type);
            $this->assertSame('2026-10-07', $tx->date->toDateString());
            $this->assertSame(TransactionStatus::Completed, $tx->status);
            $this->assertSame(1500, $tx->amount);
            $this->assertSame('FBU', $tx->currency);
            $this->assertSame($type->defaultPaymentStatus(), $tx->payment_status);
            $this->assertNotNull($tx->created_at);
            $this->assertNotNull($tx->updated_at);
        }

        $this->assertSame(count(TransactionType::cases()), Transaction::query()->count());
    }

    public function test_engine_is_idempotent_for_the_same_source(): void
    {
        $fixture = $this->createTenantFixture('txn-idem', 'txn-idem@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $engine = app(TransactionEngine::class);
        $source = $fixture['product'];

        $first = $engine->recordFromArray([
            'tenant_id' => $fixture['tenant']->id,
            'branch_id' => $fixture['branch']->id,
            'user_id' => $fixture['user']->id,
            'type' => TransactionType::Adjustment->value,
            'amount' => 100,
            'currency' => 'FBU',
            'source' => $source,
        ]);

        $second = $engine->recordFromArray([
            'tenant_id' => $fixture['tenant']->id,
            'branch_id' => $fixture['branch']->id,
            'user_id' => $fixture['user']->id,
            'type' => TransactionType::Adjustment->value,
            'amount' => 250,
            'currency' => 'FBU',
            'payment_status' => TransactionPaymentStatus::NotApplicable->value,
            'source' => $source,
        ]);

        $this->assertSame($first->id, $second->id);
        $this->assertSame(250, $second->amount);
        $this->assertSame(1, Transaction::query()->count());
    }

    public function test_engine_is_idempotent_for_the_same_idempotency_key(): void
    {
        $fixture = $this->createTenantFixture('txn-key', 'txn-key@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $engine = app(TransactionEngine::class);
        $key = (string) \Illuminate\Support\Str::uuid();

        $first = $engine->recordFromArray([
            'tenant_id' => $fixture['tenant']->id,
            'branch_id' => $fixture['branch']->id,
            'user_id' => $fixture['user']->id,
            'type' => TransactionType::Expense->value,
            'amount' => 900,
            'currency' => 'FBU',
            'idempotency_key' => $key,
        ]);

        $second = $engine->recordFromArray([
            'tenant_id' => $fixture['tenant']->id,
            'branch_id' => $fixture['branch']->id,
            'user_id' => $fixture['user']->id,
            'type' => TransactionType::Expense->value,
            'amount' => 1200,
            'currency' => 'FBU',
            'idempotency_key' => $key,
        ]);

        $this->assertSame($first->id, $second->id);
        $this->assertSame(900, $second->amount);
        $this->assertSame($key, $second->idempotency_key);
        $this->assertSame($second->id, $second->toSummaryArray()['transaction_id']);
        $this->assertSame($key, $second->toSummaryArray()['idempotency_key']);
        $this->assertSame(1, Transaction::query()->count());
    }

    public function test_api_lists_and_shows_transactions(): void
    {
        $fixture = $this->createTenantFixture('txn-api', 'txn-api@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $tx = app(TransactionEngine::class)->recordFromArray([
            'tenant_id' => $fixture['tenant']->id,
            'branch_id' => $fixture['branch']->id,
            'user_id' => $fixture['user']->id,
            'type' => TransactionType::Sale->value,
            'amount' => 5000,
            'currency' => 'FBU',
            'payment_status' => TransactionPaymentStatus::Paid->value,
        ]);

        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $list = $this->getJson('/api/v1/transactions', $headers);

        $list->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.id', $tx->id)
            ->assertJsonPath('data.0.type', 'sale');

        $show = $this->getJson('/api/v1/transactions/'.$tx->id, $headers);

        $show->assertOk()
            ->assertJsonPath('data.reference', $tx->reference)
            ->assertJsonPath('data.amount', 5000);

        $types = $this->getJson('/api/v1/transactions/types', $headers);

        $types->assertOk()
            ->assertJsonCount(7, 'data.types');
    }

    public function test_void_marks_transaction_as_voided(): void
    {
        $fixture = $this->createTenantFixture('txn-void', 'txn-void@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $engine = app(TransactionEngine::class);
        $tx = $engine->recordFromArray([
            'tenant_id' => $fixture['tenant']->id,
            'type' => TransactionType::Expense->value,
            'amount' => 800,
            'currency' => 'FBU',
            'user_id' => $fixture['user']->id,
            'branch_id' => $fixture['branch']->id,
        ]);

        $voided = $engine->void($tx, 'duplicate entry');

        $this->assertSame(TransactionStatus::Voided, $voided->status);
        $this->assertSame('duplicate entry', $voided->metadata['void_reason']);
    }
}
