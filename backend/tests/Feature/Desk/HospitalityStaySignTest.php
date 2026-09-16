<?php

namespace Tests\Feature\Desk;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class HospitalityStaySignTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_public_signature_marks_stay_signed_and_hides_binary_from_snapshot(): void
    {
        $headers = $this->hotelHeaders('hotel-stay-sign', 'hotel-stay-sign@test.local');
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $checkIn = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'walk_in_check_in',
            'guest_name' => 'Client Signature',
            'guest_email' => 'sign@exemple.com',
            'guest_phone' => '+243800000099',
            'nationality' => 'Congolaise',
            'birth_place' => 'Kinshasa',
            'profession' => 'Libérale',
            'purpose' => 'Tourisme',
            'id_document_type' => 'passport',
            'id_document_number' => 'SG-1',
            'room_id' => 'room-201',
            'arrive_on' => now()->toDateString(),
            'depart_on' => now()->addDay()->toDateString(),
        ], $headers)->assertOk();

        $stay = collect($checkIn->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Client Signature');
        $this->assertIsArray($stay);

        $link = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'create_stay_sign_link',
            'reservation_id' => $stay['id'],
        ], $headers)->assertOk();

        $linked = collect($link->json('data.docs'))
            ->first(fn ($doc) => ($doc['id'] ?? null) === $stay['id']);
        $this->assertIsArray($linked);
        $this->assertNotEmpty($linked['sign_token'] ?? null);
        $this->assertFalse((bool) ($linked['has_signature'] ?? false));

        $token = (string) $linked['sign_token'];
        $this->getJson('/api/v1/public/stay-sign/'.$token)->assertOk()
            ->assertJsonPath('data.has_signature', false);

        $tinyPng = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
        $this->postJson('/api/v1/public/stay-sign/'.$token, [
            'guest_signature_data' => $tinyPng,
        ])->assertOk()
            ->assertJsonPath('data.has_signature', true);

        $snapshot = $this->getJson('/api/v1/hospitality', $headers)->assertOk();
        $signed = collect($snapshot->json('data.docs'))
            ->first(fn ($doc) => ($doc['id'] ?? null) === $stay['id']);
        $this->assertIsArray($signed);
        $this->assertTrue((bool) ($signed['has_signature'] ?? false));
        $this->assertNotEmpty($signed['guest_signed_at'] ?? null);
        $this->assertArrayNotHasKey('guest_signature_data', $signed);

        $full = $this->getJson('/api/v1/hospitality/docs/'.$stay['id'], $headers)->assertOk();
        $this->assertTrue((bool) $full->json('data.has_signature'));
        $this->assertStringStartsWith('data:image/png', (string) $full->json('data.guest_signature_data'));
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
