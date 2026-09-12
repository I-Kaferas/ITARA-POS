<?php

namespace Tests\Feature\Api\V1;

use Tests\TestCase;

class HealthTest extends TestCase
{
    public function test_health_endpoint_returns_ok(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response->assertOk()
            ->assertJsonStructure(['status', 'service', 'version', 'timestamp'])
            ->assertJson(['status' => 'ok', 'service' => 'pos-api']);
    }

    public function test_ready_endpoint_returns_checks(): void
    {
        $response = $this->getJson('/api/v1/ready');

        $response->assertJsonStructure([
            'status',
            'checks' => ['database', 'redis'],
            'timestamp',
        ]);
    }
}
