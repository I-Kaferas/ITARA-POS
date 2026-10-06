<?php

namespace Tests\Feature\Realtime;

use App\Models\RealtimeOutbox;
use App\Services\Realtime\ChannelAuthorizer;
use App\Services\Realtime\RealtimePublisher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class RealtimeOutboxTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_event_is_stored_only_after_the_transaction_commits(): void
    {
        $fixture = $this->createTenantFixture('rt-commit', 'rt-commit@test.local');
        $publisher = app(RealtimePublisher::class);

        try {
            DB::transaction(function () use ($publisher, $fixture): void {
                $publisher->notify(
                    type: 'sale.created',
                    tenantId: $fixture['tenant']->id,
                    storeId: $fixture['store']->id,
                    entity: 'sale',
                    id: $fixture['product']->id,
                );

                throw new \RuntimeException('rollback');
            });
        } catch (\RuntimeException) {
            // expected
        }

        $this->assertSame(0, RealtimeOutbox::query()->where('event_name', 'sale.created')->count());

        $publisher->notify(
            type: 'sale.created',
            tenantId: $fixture['tenant']->id,
            storeId: $fixture['store']->id,
            entity: 'sale',
            id: $fixture['product']->id,
            data: ['number' => 'INV-1'],
        );

        $stored = RealtimeOutbox::query()->where('event_name', 'sale.created')->first();
        $this->assertNotNull($stored);
        $this->assertSame('sale.created', $stored->event_name);
        $this->assertSame($fixture['tenant']->id, $stored->tenant_id);
        $this->assertNull($stored->broadcast_at);

        $publisher->broadcastStored($stored->id);
        $this->assertNotNull($stored->fresh()->broadcast_at);
    }

    public function test_tenant_cannot_read_another_tenants_events(): void
    {
        $tenantA = $this->createTenantFixture('rt-a', 'rt-a@test.local');
        $tenantB = $this->createTenantFixture('rt-b', 'rt-b@test.local');
        $publisher = app(RealtimePublisher::class);

        $publisher->notify('sale.created', $tenantA['tenant']->id, $tenantA['store']->id, 'sale', $tenantA['product']->id);
        $publisher->notify('sale.created', $tenantB['tenant']->id, $tenantB['store']->id, 'sale', $tenantB['product']->id);

        $response = $this->getJson('/api/v1/realtime/sync', $this->tenantHeaders($tenantA['token'], $tenantA['tenant']));

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('tenant_id')->unique()->values()->all();
        $this->assertSame([$tenantA['tenant']->id], $ids);
    }

    public function test_store_channel_rejects_a_user_assigned_to_another_store(): void
    {
        $tenantA = $this->createTenantFixture('rt-store-a', 'rt-store-a@test.local');
        $tenantB = $this->createTenantFixture('rt-store-b', 'rt-store-b@test.local');
        $tenantA['user']->stores()->attach($tenantA['store']->id);

        $authorizer = app(ChannelAuthorizer::class);

        $this->assertTrue($authorizer->allowsStore($tenantA['user'], $tenantA['tenant']->id, $tenantA['store']->id));
        $this->assertFalse($authorizer->allowsStore($tenantA['user'], $tenantB['tenant']->id, $tenantB['store']->id));
        $this->assertFalse($authorizer->allowsTenant($tenantA['user'], $tenantB['tenant']->id));
    }

    public function test_broadcast_uses_the_domain_event_name(): void
    {
        $fixture = $this->createTenantFixture('rt-name', 'rt-name@test.local');

        app(RealtimePublisher::class)->notify(
            type: 'stock.updated',
            tenantId: $fixture['tenant']->id,
            entity: 'product',
            id: $fixture['product']->id,
            data: ['quantity' => -2],
        );

        $stored = RealtimeOutbox::query()->where('event_name', 'stock.updated')->firstOrFail();
        $event = new \App\Events\Realtime\RealtimeEvent($stored->envelope());

        $this->assertSame('stock.updated', $event->broadcastAs());
        $this->assertSame(-2, $event->broadcastWith()['data']['quantity']);
        $this->assertNotEmpty($event->broadcastOn());
    }

    public function test_shift_and_purchase_observers_write_the_outbox_inside_the_transaction(): void
    {
        $fixture = $this->createTenantFixture('rt-domains', 'rt-domains@test.local');
        $shift = new \App\Models\CashierShift([
            'tenant_id' => $fixture['tenant']->id,
            'status' => \App\Enums\CashierShiftStatus::Open,
            'expected_cash' => 500000,
            'sales_total' => 0,
        ]);
        $shift->id = (string) \Illuminate\Support\Str::uuid();

        app(\App\Observers\Realtime\CashierShiftObserver::class)->created($shift);

        $order = new \App\Models\PurchaseOrder([
            'tenant_id' => $fixture['tenant']->id,
            'status' => \App\Enums\PurchaseOrderStatus::Approved,
            'order_number' => 'PO-1',
            'total' => 1200,
        ]);
        $order->id = (string) \Illuminate\Support\Str::uuid();
        $order->syncOriginal();
        app(\App\Observers\Realtime\PurchaseOrderObserver::class)->updated($order);

        $this->assertDatabaseHas('realtime_outbox', [
            'event_name' => 'shift.opened',
            'tenant_id' => $fixture['tenant']->id,
        ]);
        $this->assertDatabaseHas('realtime_outbox', [
            'event_name' => 'purchase.updated',
            'tenant_id' => $fixture['tenant']->id,
        ]);
    }
}
