<?php

namespace Tests\Feature\Desk;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class HospitalityWalkInTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_walk_in_checks_in_guest_and_occupies_room(): void
    {
        $headers = $this->hotelHeaders('hotel-walkin', 'hotel-walkin@test.local');
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $response = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'walk_in_check_in',
            'guest_name' => 'Jean Dupont',
            'guest_email' => 'jean@exemple.com',
            'guest_phone' => '+243800000001',
            'nationality' => 'Congolaise',
            'birth_place' => 'Kinshasa',
            'profession' => 'Libérale',
            'id_document_type' => 'passport',
            'id_document_number' => 'OP123456',
            'id_document_issue_place' => 'Kinshasa',
            'room_id' => 'room-201',
            'arrive_on' => now()->toDateString(),
            'depart_on' => now()->addDay()->toDateString(),
        ], $headers)->assertOk();

        $stay = collect($response->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Jean Dupont');
        $room = collect($response->json('data.docs'))
            ->first(fn ($doc) => ($doc['id'] ?? null) === 'room-201');

        $this->assertIsArray($stay);
        $this->assertSame('checked_in', $stay['status']);
        $this->assertSame('walk_in', $stay['channel']);
        $this->assertTrue($stay['walk_in']);
        $this->assertSame('Congolaise', $stay['nationality']);
        $this->assertSame('passport', $stay['id_document_type']);
        $this->assertSame('OP123456', $stay['id_document_number']);
        $this->assertSame('room-201', $stay['room_id']);
        $this->assertIsArray($room);
        $this->assertSame('occupied', $room['status']);
        $this->assertSame('Jean Dupont', $room['guest_name']);
    }

    public function test_walk_in_requires_identity_fields(): void
    {
        $headers = $this->hotelHeaders('hotel-walkin-id', 'hotel-walkin-id@test.local');
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'walk_in_check_in',
            'guest_name' => 'Jean Dupont',
            'room_id' => 'room-201',
            'arrive_on' => now()->toDateString(),
            'depart_on' => now()->addDay()->toDateString(),
        ], $headers)->assertStatus(422);
    }

    public function test_walk_in_rejects_occupied_room(): void
    {
        $headers = $this->hotelHeaders('hotel-walkin-occ', 'hotel-walkin-occ@test.local');
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $payload = [
            'action' => 'walk_in_check_in',
            'guest_name' => 'Jean Dupont',
            'nationality' => 'Congolaise',
            'id_document_type' => 'national_id',
            'id_document_number' => 'CD-1',
            'room_id' => 'room-201',
            'arrive_on' => now()->toDateString(),
            'depart_on' => now()->addDay()->toDateString(),
        ];

        $this->postJson('/api/v1/hospitality/actions', $payload, $headers)->assertOk();
        $this->postJson('/api/v1/hospitality/actions', array_merge($payload, [
            'guest_name' => 'Autre Client',
            'id_document_number' => 'CD-2',
        ]), $headers)->assertStatus(422);
    }

    /** @return array<string, string> */
    private function hotelHeaders(string $slug, string $email): array
    {
        $fixture = $this->createTenantFixture($slug, $email);

        return array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );
    }
}
