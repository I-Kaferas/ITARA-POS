<?php

namespace Tests\Feature\Desk;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class HospitalityTableTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_tables_can_be_created_updated_and_deleted(): void
    {
        $headers = $this->hospitalityHeaders();
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $created = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_table',
            'label' => 'T10',
            'seats' => 6,
            'zone_id' => 'zone-salle',
            'shape' => 'oval',
        ], $headers)->assertOk();

        $table = collect($created->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'table' && ($doc['label'] ?? '') === 'T10');

        $this->assertIsArray($table);
        $this->assertSame(6, $table['seats']);
        $this->assertSame('oval', $table['shape']);
        $this->assertSame('zone-salle', $table['zone_id']);
        $this->assertSame('free', $table['status']);

        $updated = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_table',
            'id' => $table['id'],
            'label' => 'VIP 10',
            'seats' => 8,
            'zone_id' => 'zone-terrasse',
            'shape' => 'rect',
        ], $headers)->assertOk();

        $fresh = collect($updated->json('data.docs'))
            ->first(fn ($doc) => ($doc['id'] ?? null) === $table['id']);
        $this->assertSame('VIP 10', $fresh['label']);
        $this->assertSame(8, $fresh['seats']);
        $this->assertSame('zone-terrasse', $fresh['zone_id']);

        $deleted = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'delete_table',
            'id' => $table['id'],
        ], $headers)->assertOk();

        $stillThere = collect($deleted->json('data.docs'))
            ->first(fn ($doc) => ($doc['id'] ?? null) === $table['id']);
        $this->assertNull($stillThere);
    }

    public function test_occupied_table_cannot_be_deleted(): void
    {
        $headers = $this->hospitalityHeaders();
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'open_order',
            'table_id' => 'table-1',
        ], $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'delete_table',
            'id' => 'table-1',
        ], $headers)->assertUnprocessable();
    }

    public function test_zone_cannot_be_deleted_while_tables_use_it(): void
    {
        $headers = $this->hospitalityHeaders();
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'delete_zone',
            'id' => 'zone-salle',
        ], $headers)->assertUnprocessable();

        $created = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_zone',
            'name' => 'Bar',
        ], $headers)->assertOk();

        $zone = collect($created->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'zone' && ($doc['name'] ?? '') === 'Bar');
        $this->assertIsArray($zone);

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'delete_zone',
            'id' => $zone['id'],
        ], $headers)->assertOk();
    }

    /** @return array<string, string> */
    private function hospitalityHeaders(): array
    {
        $fixture = $this->createTenantFixture('rest-tables', 'rest-tables@test.local');

        return array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );
    }
}
