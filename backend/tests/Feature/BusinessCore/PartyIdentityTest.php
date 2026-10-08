<?php

namespace Tests\Feature\BusinessCore;

use App\Enums\PartyContext;
use App\Models\Customer;
use App\Models\Employee;
use App\Models\Party;
use App\Models\Supplier;
use App\Services\BusinessCore\BusinessCore;
use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class PartyIdentityTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_one_party_can_be_pos_customer_restaurant_hotel_guest_and_crm_contact(): void
    {
        $fixture = $this->createTenantFixture('party-core', 'party-core@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $created = $this->postJson('/api/v1/parties', [
            'display_name' => 'Aline Ndayishimiye',
            'email' => 'aline@shared.test',
            'phone' => '+25760001111',
            'roles' => ['customer', 'crm'],
            'contexts' => ['pos', 'restaurant', 'hotel', 'crm'],
            'crm_role' => 'client',
        ], $headers)->assertCreated()->json('data');

        $partyId = $created['party']['id'];
        $this->assertSame('Aline Ndayishimiye', $created['party']['display_name']);
        $this->assertContains('customer', $created['roles']);
        $this->assertNotNull($created['customer']['id']);

        $contexts = collect($created['contexts'])->pluck('context')->all();
        $this->assertContains('pos', $contexts);
        $this->assertContains('restaurant', $contexts);
        $this->assertContains('hotel', $contexts);
        $this->assertContains('crm', $contexts);

        $this->getJson('/api/v1/customers/'.$created['customer']['id'], $headers)
            ->assertOk()
            ->assertJsonPath('data.email', 'aline@shared.test')
            ->assertJsonPath('data.party_id', $partyId);

        $this->getJson('/api/v1/crm/customers/'.$created['customer']['id'].'/dossier', $headers)
            ->assertOk()
            ->assertJsonPath('data.customer.id', $created['customer']['id']);

        $this->postJson('/api/v1/parties/'.$partyId.'/contexts', [
            'context' => 'loyalty',
            'label' => 'Loyalty Member',
        ], $headers)->assertCreated();

        $dossier = $this->getJson('/api/v1/parties/'.$partyId, $headers)->assertOk()->json('data');
        $this->assertCount(1, collect($dossier['contexts'])->where('context', 'loyalty'));
        $this->assertSame($created['customer']['id'], $dossier['customer']['id']);
    }

    public function test_same_identity_can_be_customer_and_supplier_without_duplicating_party(): void
    {
        $fixture = $this->createTenantFixture('party-dual', 'party-dual@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        app(TenantContext::class)->bind($fixture['tenant']);

        $customer = $this->postJson('/api/v1/customers', [
            'name' => 'Maison Verte',
            'email' => 'achat@maisonverte.test',
            'phone' => '+25761112222',
            'tax_id' => 'TIN-MV-001',
        ], $headers)->assertCreated()->json('data');

        $supplier = $this->postJson('/api/v1/suppliers', [
            'name' => 'Maison Verte',
            'email' => 'achat@maisonverte.test',
            'phone' => '+25761112222',
            'tax_id' => 'TIN-MV-001',
            'code' => 'SUP-MV',
        ], $headers)->assertCreated()->json('data');

        $this->assertNotNull($customer['party_id']);
        $this->assertSame($customer['party_id'], $supplier['party_id']);

        $party = Party::query()->findOrFail($customer['party_id']);
        $this->assertTrue($party->customer()->exists());
        $this->assertTrue($party->supplier()->exists());
        $this->assertEqualsCanonicalizing(['customer', 'supplier'], $party->roleNames());

        $core = app(BusinessCore::class);
        $dossier = $core->parties->dossier($party);
        $this->assertSame($customer['id'], $dossier['customer']->id);
        $this->assertSame($supplier['id'], $dossier['supplier']->id);
    }

    public function test_employee_role_attaches_to_existing_party(): void
    {
        $fixture = $this->createTenantFixture('party-emp', 'party-emp@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        app(TenantContext::class)->bind($fixture['tenant']);

        $party = $this->postJson('/api/v1/parties', [
            'display_name' => 'Jean Cashier',
            'email' => 'jean@staff.test',
            'roles' => ['customer'],
        ], $headers)->assertCreated()->json('data.party');

        $this->postJson('/api/v1/parties/'.$party['id'].'/roles', [
            'role' => 'employee',
            'job_title' => 'Cashier',
            'department' => 'POS',
            'user_id' => $fixture['user']->id,
        ], $headers)->assertOk();

        $employee = Employee::query()->where('party_id', $party['id'])->first();
        $this->assertNotNull($employee);
        $this->assertSame('Cashier', $employee->job_title);
        $this->assertSame($fixture['user']->id, $employee->user_id);

        $fixture['user']->refresh();
        $this->assertSame($party['id'], $fixture['user']->party_id);

        $this->assertSame(1, Customer::query()->where('party_id', $party['id'])->count());
        $this->assertSame(1, Employee::query()->where('party_id', $party['id'])->count());
        $this->assertSame(0, Supplier::query()->where('party_id', $party['id'])->count());
    }

    public function test_crm_lead_conversion_reuses_party_backed_customer(): void
    {
        $fixture = $this->createTenantFixture('party-crm', 'party-crm@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $account = $this->postJson('/api/v1/crm/accounts', [
            'name' => 'Hotel Lac',
            'email' => 'ops@hotellac.test',
        ], $headers)->assertCreated()->json('data');

        $this->assertNotNull($account['party_id']);

        $lead = $this->postJson('/api/v1/crm/leads', [
            'name' => 'Guest Marie',
            'email' => 'marie@guest.test',
            'phone' => '+25762223333',
            'crm_account_id' => $account['id'],
        ], $headers)->assertCreated()->json('data');

        $customer = $this->postJson('/api/v1/crm/leads/'.$lead['id'].'/convert', [
            'crm_role' => 'client',
        ], $headers)->assertOk()->json('data');

        $this->assertNotNull($customer['party_id']);
        $this->assertSame('client', $customer['crm_role']);

        app(TenantContext::class)->bind($fixture['tenant']);
        $party = Party::query()->findOrFail($customer['party_id']);
        app(BusinessCore::class)->parties->attachContext($party, PartyContext::Hotel);

        $dossier = $this->getJson('/api/v1/parties/'.$party->id, $headers)->assertOk()->json('data');
        $this->assertContains('customer', $dossier['roles']);
        $this->assertTrue(collect($dossier['contexts'])->contains(fn ($c) => $c['context'] === 'hotel'));
    }

    public function test_business_core_entity_map_is_exposed(): void
    {
        $fixture = $this->createTenantFixture('party-map', 'party-map@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $entities = $this->getJson('/api/v1/business-core/entities', $headers)
            ->assertOk()
            ->json('data');

        foreach ([
            'party', 'customer', 'supplier', 'employee', 'product', 'service',
            'location', 'transaction', 'payment', 'document', 'user', 'organization',
        ] as $key) {
            $this->assertArrayHasKey($key, $entities);
        }
    }
}
