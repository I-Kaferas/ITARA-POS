<?php

namespace Tests\Feature\Desk;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class HospitalityHousekeepingTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_marking_a_room_dirty_creates_a_housekeeping_task(): void
    {
        $headers = $this->headers();

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $response = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'set_room_housekeeping',
            'id' => 'room-201',
            'housekeeping_status' => 'dirty',
            'hk_priority' => 'high',
            'notes' => 'Check-out du matin',
        ], $headers)->assertOk();

        $docs = collect($response->json('data.docs'));
        $room = $docs->first(fn ($doc) => ($doc['kind'] ?? null) === 'room' && ($doc['id'] ?? '') === 'room-201');
        $task = $docs->first(fn ($doc) => ($doc['kind'] ?? null) === 'housekeeping_task');

        $this->assertIsArray($room);
        $this->assertSame('dirty', $room['housekeeping_status']);
        $this->assertSame('high', $room['hk_priority']);
        $this->assertSame('Check-out du matin', $room['notes']);

        $this->assertIsArray($task);
        $this->assertSame('room-201', $task['room_id']);
        $this->assertSame('201', $task['room_number']);
        $this->assertSame('cleaning', $task['type']);
        $this->assertSame('pending', $task['status']);
        $this->assertSame('high', $task['priority']);
        $this->assertSame('HK-001', $task['task_no']);
    }

    public function test_cleaning_a_room_completes_open_tasks(): void
    {
        $headers = $this->headers();
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'set_room_housekeeping',
            'id' => 'room-201',
            'housekeeping_status' => 'dirty',
        ], $headers)->assertOk();

        $response = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'set_room_housekeeping',
            'id' => 'room-201',
            'housekeeping_status' => 'clean',
        ], $headers)->assertOk();

        $task = collect($response->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'housekeeping_task');

        $this->assertIsArray($task);
        $this->assertSame('done', $task['status']);
    }

    public function test_housekeeping_task_can_be_created_and_started(): void
    {
        $headers = $this->headers();
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $created = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_housekeeping_task',
            'room_id' => 'room-203',
            'type' => 'cleaning',
            'priority' => 'normal',
            'status' => 'pending',
            'assignee_name' => 'Marie',
            'notes' => 'Draps',
        ], $headers)->assertOk();

        $task = collect($created->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'housekeeping_task');
        $room = collect($created->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'room' && ($doc['id'] ?? '') === 'room-203');

        $this->assertIsArray($task);
        $this->assertSame('assigned', $task['status']);
        $this->assertSame('Marie', $task['assignee_name']);
        $this->assertIsArray($room);
        $this->assertSame('dirty', $room['housekeeping_status']);

        $started = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'set_housekeeping_task_status',
            'id' => $task['id'],
            'status' => 'in_progress',
        ], $headers)->assertOk();

        $updatedTask = collect($started->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'housekeeping_task' && ($doc['id'] ?? '') === $task['id']);
        $updatedRoom = collect($started->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'room' && ($doc['id'] ?? '') === 'room-203');

        $this->assertIsArray($updatedTask);
        $this->assertSame('in_progress', $updatedTask['status']);
        $this->assertIsArray($updatedRoom);
        $this->assertSame('cleaning', $updatedRoom['housekeeping_status']);
    }

    public function test_unassigned_task_stays_pending_and_assignment_moves_it(): void
    {
        $headers = $this->headers();
        $this->getJson('/api/v1/hospitality', $headers)->assertOk();

        $created = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'upsert_housekeeping_task',
            'room_id' => 'room-301',
            'type' => 'cleaning',
            'priority' => 'low',
            'status' => 'pending',
        ], $headers)->assertOk();

        $task = collect($created->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'housekeeping_task');

        $this->assertIsArray($task);
        $this->assertSame('pending', $task['status']);
        $this->assertNull($task['assignee_name'] ?? null);

        $assigned = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'set_housekeeping_task_status',
            'id' => $task['id'],
            'status' => 'assigned',
            'assignee_id' => 'user-alain',
            'assignee_name' => 'Alain',
        ], $headers)->assertOk();

        $updated = collect($assigned->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'housekeeping_task' && ($doc['id'] ?? '') === $task['id']);

        $this->assertIsArray($updated);
        $this->assertSame('assigned', $updated['status']);
        $this->assertSame('Alain', $updated['assignee_name']);
    }

    /** @return array<string, string> */
    private function headers(): array
    {
        $fixture = $this->createTenantFixture('hotel-hk', 'hotel-hk@test.local');

        return array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );
    }
}
