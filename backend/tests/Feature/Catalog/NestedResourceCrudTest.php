<?php

namespace Tests\Feature\Catalog;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class NestedResourceCrudTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_customer_addresses_crud(): void
    {
        $fixture = $this->createTenantFixture('addr-crud', 'addr-crud@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $customerId = $fixture['customer']->id;

        $created = $this->postJson("/api/v1/customers/{$customerId}/addresses", [
            'label' => 'home',
            'line1' => 'Avenue de l\'Independance',
            'city' => 'Bujumbura',
            'country_code' => 'BI',
            'is_primary' => true,
        ], $headers)->assertCreated();

        $addressId = $created->json('data.id');

        $this->getJson("/api/v1/customers/{$customerId}/addresses", $headers)
            ->assertOk()
            ->assertJsonFragment(['line1' => 'Avenue de l\'Independance']);

        $this->patchJson("/api/v1/customer-addresses/{$addressId}", [
            'city' => 'Gitega',
        ], $headers)->assertOk()->assertJsonPath('data.city', 'Gitega');

        $this->deleteJson("/api/v1/customer-addresses/{$addressId}", [], $headers)
            ->assertOk();
    }

    public function test_supplier_contacts_crud(): void
    {
        $fixture = $this->createTenantFixture('contact-crud', 'contact-crud@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $supplierId = $fixture['supplier']->id;

        $created = $this->postJson("/api/v1/suppliers/{$supplierId}/contacts", [
            'name' => 'Jean Contact',
            'email' => 'jean@test.local',
            'phone' => '68001122',
            'is_primary' => true,
        ], $headers)->assertCreated();

        $contactId = $created->json('data.id');

        $this->getJson("/api/v1/suppliers/{$supplierId}/contacts", $headers)
            ->assertOk()
            ->assertJsonFragment(['name' => 'Jean Contact']);

        $this->patchJson("/api/v1/supplier-contacts/{$contactId}", [
            'phone' => '69001122',
        ], $headers)->assertOk()->assertJsonPath('data.phone', '69001122');

        $this->deleteJson("/api/v1/supplier-contacts/{$contactId}", [], $headers)
            ->assertOk();
    }

    public function test_inventory_movement_create_and_list(): void
    {
        $fixture = $this->createTenantFixture('move-crud', 'move-crud@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $warehouseId = $fixture['warehouse']->id;

        $this->postJson("/api/v1/warehouses/{$warehouseId}/movements", [
            'product_id' => $fixture['product']->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
            'notes' => 'Stock initial',
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/warehouses/{$warehouseId}/movements", $headers)
            ->assertOk()
            ->assertJsonPath('data.data.0.movement_type', 'INITIAL_STOCK');
    }

    public function test_store_sale_returns_index_is_available(): void
    {
        $fixture = $this->createTenantFixture('returns-list', 'returns-list@test.local');

        $this->getJson(
            "/api/v1/stores/{$fixture['store']->id}/sale-returns",
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
        )->assertOk()->assertJsonStructure(['data']);
    }
}
