<?php

namespace Tests\Feature\Desk;

use App\Models\DeskDocument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class HospitalityAmenityTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_amenity_code_is_generated_from_name(): void
    {
        $fixture = $this->createTenantFixture('hotel-amenity', 'hotel-amenity@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );

        $response = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_amenity',
            'name' => 'Coffre biométrique',
            'category' => 'other',
            'replacement_value_cents' => 2500,
            'display_order' => 3,
            'icon_key' => 'wifi',
            'is_active' => true,
        ], $headers)->assertOk();

        $amenity = collect($response->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'amenity' && ($doc['name'] ?? '') === 'Coffre biométrique');

        $this->assertIsArray($amenity);
        $this->assertSame('COFFRE_BIOMETRIQUE', $amenity['code']);
        $this->assertSame('other', $amenity['category']);
        $this->assertSame(2500, $amenity['replacement_value_cents']);
        $this->assertSame(3, $amenity['display_order']);
        $this->assertSame('wifi', $amenity['icon_key']);
        $this->assertTrue($amenity['is_active']);
    }

    public function test_amenity_cannot_be_deleted_when_used_by_room_type(): void
    {
        $fixture = $this->createTenantFixture('hotel-amenity-use', 'hotel-amenity-use@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        DeskDocument::query()
            ->where('store_id', $fixture['store']->id)
            ->where('code', 'type-standard')
            ->update([
                'payload' => array_merge(
                    DeskDocument::query()
                        ->where('store_id', $fixture['store']->id)
                        ->where('code', 'type-standard')
                        ->value('payload') ?? [],
                    ['amenity_ids' => ['amenity-wifi']],
                ),
            ]);

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'delete_amenity',
            'id' => 'amenity-wifi',
        ], $headers)->assertStatus(422);
    }

    public function test_room_can_store_extra_amenities(): void
    {
        $fixture = $this->createTenantFixture('hotel-room-amenity', 'hotel-room-amenity@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $room = DeskDocument::query()
            ->where('store_id', $fixture['store']->id)
            ->where('code', 'room-201')
            ->first();
        $this->assertNotNull($room);

        DeskDocument::query()
            ->where('store_id', $fixture['store']->id)
            ->where('code', 'room-201')
            ->update([
                'payload' => array_merge($room->payload ?? [], [
                    'amenity_ids' => ['amenity-safe'],
                    'building_id' => $room->payload['building_id'] ?? 'building-main',
                    'floor_id' => $room->payload['floor_id'] ?? 'floor-1',
                    'type_id' => 'type-standard',
                ]),
            ]);

        $docs = $this->getJson('/api/v1/hospitality?kinds='.urlencode('room,amenity'), $headers)
            ->assertOk()
            ->json('data.docs');

        $updated = collect($docs)->first(fn ($doc) => ($doc['id'] ?? null) === 'room-201');
        $this->assertIsArray($updated);
        $this->assertSame(['amenity-safe'], $updated['amenity_ids']);
    }

    public function test_checkout_charges_missing_amenity_on_folio(): void
    {
        $fixture = $this->createTenantFixture('hotel-missing-amenity', 'hotel-missing-amenity@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        DeskDocument::query()
            ->where('store_id', $fixture['store']->id)
            ->where('code', 'amenity-tv')
            ->update([
                'payload' => array_merge(
                    DeskDocument::query()
                        ->where('store_id', $fixture['store']->id)
                        ->where('code', 'amenity-tv')
                        ->value('payload') ?? [],
                    ['replacement_value_cents' => 15000],
                ),
            ]);

        DeskDocument::query()
            ->where('store_id', $fixture['store']->id)
            ->where('code', 'type-standard')
            ->update([
                'payload' => array_merge(
                    DeskDocument::query()
                        ->where('store_id', $fixture['store']->id)
                        ->where('code', 'type-standard')
                        ->value('payload') ?? [],
                    ['amenity_ids' => ['amenity-tv']],
                ),
            ]);

        $checkIn = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'walk_in_check_in',
            'guest_name' => 'Marie Kabila',
            'guest_email' => 'marie@exemple.com',
            'nationality' => 'Congolaise',
            'id_document_type' => 'passport',
            'id_document_number' => 'OP999',
            'purpose' => 'Affaires',
            'room_id' => 'room-201',
            'arrive_on' => now()->toDateString(),
            'depart_on' => now()->addDay()->toDateString(),
        ], $headers)->assertOk();

        $stay = collect($checkIn->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Marie Kabila');

        $this->assertIsArray($stay);
        $this->assertNotEmpty($stay['inventory_amenities'] ?? []);
        $this->assertTrue(collect($stay['inventory_amenities'])->contains(fn ($item) => ($item['id'] ?? '') === 'amenity-tv'));

        $checkout = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'check_out',
            'reservation_id' => $stay['id'],
            'missing_items' => [
                ['amenity_id' => 'amenity-tv', 'condition' => 'missing'],
            ],
        ], $headers)->assertOk();

        $folio = collect($checkout->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'folio' && ($doc['reservation_id'] ?? null) === $stay['id']);

        $this->assertIsArray($folio);
        $missing = collect($folio['lines'] ?? [])
            ->first(fn ($line) => ($line['kind'] ?? '') === 'missing_amenity');
        $this->assertIsArray($missing);
        $this->assertSame(15000, $missing['amount']);
        $this->assertStringContainsString('Télévision', (string) ($missing['description'] ?? ''));
    }
}
