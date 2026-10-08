<?php

namespace Tests\Feature\Realtime;

use App\Models\RealtimeOutbox;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class HospitalityRealtimeTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_kitchen_and_hotel_actions_publish_live_events(): void
    {
        $fixture = $this->createTenantFixture('rt-desk', 'rt-desk@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();
        $this->assertSame(0, RealtimeOutbox::query()->where('event_name', 'like', 'kitchen.%')->count());
        $this->assertSame(0, RealtimeOutbox::query()->where('event_name', 'like', 'hotel.%')->count());

        $opened = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'open_order',
            'table_id' => 'table-1',
        ], $headers)->assertOk();

        $order = collect($opened->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'order');
        $this->assertIsArray($order);

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'add_line',
            'order_id' => $order['id'],
            'name' => 'Poulet',
            'unit_price' => 1500,
            'quantity' => 1,
            'course' => 'plat',
        ], $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'send_course',
            'order_id' => $order['id'],
            'course' => 'plat',
        ], $headers)->assertOk();

        $this->assertDatabaseHas('realtime_outbox', [
            'event_name' => 'kitchen.new',
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $fixture['store']->id,
            'entity_type' => 'ticket',
            'status' => 'new',
        ]);

        $ticketId = RealtimeOutbox::query()->where('event_name', 'kitchen.new')->value('entity_id');
        $this->assertIsString($ticketId);

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'set_ticket_status',
            'ticket_id' => $ticketId,
            'status' => 'preparing',
        ], $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'set_ticket_status',
            'ticket_id' => $ticketId,
            'status' => 'ready',
        ], $headers)->assertOk();

        $this->assertDatabaseHas('realtime_outbox', [
            'event_name' => 'kitchen.ready',
            'entity_id' => $ticketId,
            'status' => 'ready',
        ]);

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_reservation',
            'guest_name' => 'Amina Kabila',
            'space_kind' => 'guest_room',
            'type_id' => 'type-standard',
            'arrive_on' => '2026-10-10',
            'depart_on' => '2026-10-12',
            'adults' => 2,
        ], $headers)->assertOk();

        $this->assertDatabaseHas('realtime_outbox', [
            'event_name' => 'hotel.reservation.created',
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $fixture['store']->id,
            'entity_type' => 'reservation',
            'status' => 'confirmed',
        ]);
    }
}
