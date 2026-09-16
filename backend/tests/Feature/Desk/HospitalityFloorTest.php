<?php

namespace Tests\Feature\Desk;

use App\Models\DeskDocument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class HospitalityFloorTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_floor_can_be_created_for_whole_building(): void
    {
        [$headers, $buildingId] = $this->seedBuilding();

        $response = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_floor',
            'building_id' => $buildingId,
            'floor_number' => 1,
            'name' => 'Rez-de-chaussée',
            'display_order' => 0,
            'is_active' => true,
        ], $headers)->assertOk();

        $floor = collect($response->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'floor' && (int) ($doc['floor_number'] ?? 0) === 1);

        $this->assertIsArray($floor);
        $this->assertSame($buildingId, $floor['building_id']);
        $this->assertSame('OLD PENTAGONE', $floor['building_name']);
        $this->assertNull($floor['wing_id']);
        $this->assertSame('Rez-de-chaussée', $floor['name']);
        $this->assertSame(0, $floor['display_order']);
        $this->assertTrue($floor['is_active']);
    }

    public function test_floor_can_be_attached_to_a_wing(): void
    {
        [$headers, $buildingId] = $this->seedBuilding();

        $wing = collect($this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_wing',
            'building_id' => $buildingId,
            'name' => 'Est',
            'display_order' => 1,
            'is_active' => true,
        ], $headers)->assertOk()->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'wing');

        $this->assertIsArray($wing);

        $floor = collect($this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_floor',
            'building_id' => $buildingId,
            'wing_id' => $wing['id'],
            'floor_number' => 2,
            'name' => 'Étage 2',
        ], $headers)->assertOk()->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'floor');

        $this->assertIsArray($floor);
        $this->assertSame($wing['id'], $floor['wing_id']);
        $this->assertSame('Est', $floor['wing_name']);
        $this->assertSame(2, $floor['floor_number']);
    }

    public function test_duplicate_floor_number_in_same_scope_is_rejected(): void
    {
        [$headers, $buildingId] = $this->seedBuilding();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_floor',
            'building_id' => $buildingId,
            'floor_number' => 1,
        ], $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_floor',
            'building_id' => $buildingId,
            'floor_number' => 1,
        ], $headers)->assertStatus(422);
    }

    public function test_wing_from_another_building_is_rejected(): void
    {
        [$headers, $buildingId] = $this->seedBuilding();

        $otherBuilding = collect($this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_building',
            'name' => 'Annexe',
        ], $headers)->assertOk()->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'building' && ($doc['name'] ?? '') === 'Annexe');

        $wing = collect($this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_wing',
            'building_id' => $otherBuilding['id'],
            'name' => 'Ouest',
        ], $headers)->assertOk()->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'wing');

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_floor',
            'building_id' => $buildingId,
            'wing_id' => $wing['id'],
            'floor_number' => 1,
        ], $headers)->assertStatus(422);
    }

    public function test_wing_cannot_be_deleted_when_it_has_a_floor(): void
    {
        [$headers, $buildingId] = $this->seedBuilding();

        $wing = collect($this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_wing',
            'building_id' => $buildingId,
            'name' => 'Nord',
        ], $headers)->assertOk()->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'wing');

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_floor',
            'building_id' => $buildingId,
            'wing_id' => $wing['id'],
            'floor_number' => 3,
        ], $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'delete_wing',
            'id' => $wing['id'],
        ], $headers)->assertStatus(422);
    }

    public function test_floor_cannot_be_deleted_when_used_by_a_room(): void
    {
        [$headers, $buildingId, $storeId] = $this->seedBuilding();

        $floor = collect($this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_floor',
            'building_id' => $buildingId,
            'floor_number' => 1,
        ], $headers)->assertOk()->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'floor');

        DeskDocument::query()
            ->where('store_id', $storeId)
            ->where('code', 'room-201')
            ->update([
                'payload' => array_merge(
                    DeskDocument::query()
                        ->where('store_id', $storeId)
                        ->where('code', 'room-201')
                        ->value('payload') ?? [],
                    ['floor_id' => $floor['id']],
                ),
            ]);

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'delete_floor',
            'id' => $floor['id'],
        ], $headers)->assertStatus(422);
    }

    /** @return array{0: array<string, string>, 1: string, 2: string} */
    private function seedBuilding(): array
    {
        $fixture = $this->createTenantFixture('hotel-floor', 'hotel-floor@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $building = collect($this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_building',
            'name' => 'OLD PENTAGONE',
            'display_order' => 0,
            'is_active' => true,
        ], $headers)->assertOk()->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'building');

        $this->assertIsArray($building);

        return [$headers, $building['id'], $fixture['store']->id];
    }
}
