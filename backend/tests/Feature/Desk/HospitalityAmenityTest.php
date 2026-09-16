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
}
