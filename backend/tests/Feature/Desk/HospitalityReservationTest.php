<?php

namespace Tests\Feature\Desk;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class HospitalityReservationTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_upsert_reservation_books_room_type_without_assigning_room(): void
    {
        $fixture = $this->createTenantFixture('hotel-rsv', 'hotel-rsv@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $response = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_reservation',
            'guest_name' => 'Jean Dupont',
            'guest_email' => 'jean@exemple.com',
            'guest_phone' => '+243000',
            'space_kind' => 'guest_room',
            'type_id' => 'type-standard',
            'arrive_on' => '2026-10-01',
            'depart_on' => '2026-10-03',
            'adults' => 2,
            'children' => 1,
            'deposit_cents' => 5000,
            'channel' => 'direct',
            'special_requests' => 'Étage élevé',
        ], $headers)->assertOk();

        $reservation = collect($response->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Jean Dupont');

        $this->assertIsArray($reservation);
        $this->assertSame('confirmed', $reservation['status']);
        $this->assertSame('type-standard', $reservation['type_id']);
        $this->assertSame(2, $reservation['nights']);
        $this->assertNull($reservation['room_id'] ?? null);
        $this->assertSame('Étage élevé', $reservation['special_requests']);
    }
}
