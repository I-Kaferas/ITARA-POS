<?php

namespace Tests\Feature\Crm;

use App\Models\Customer;
use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class CrmTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_lead_becomes_the_same_customer_used_by_the_rest_of_the_erp(): void
    {
        $fixture = $this->createTenantFixture('crm-a', 'crm-a@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $account = $this->postJson('/api/v1/crm/accounts', [
            'name' => 'Maison Nord',
            'legal_name' => 'Maison Nord SPRL',
        ], $headers)->assertCreated()->json('data');

        $lead = $this->postJson('/api/v1/crm/leads', [
            'name' => 'Aline',
            'email' => 'aline@maison.test',
            'phone' => '+25722222222',
            'company_name' => 'Maison Nord',
            'crm_account_id' => $account['id'],
            'source' => 'visit',
        ], $headers)->assertCreated()->json('data');

        $customer = $this->postJson('/api/v1/crm/leads/'.$lead['id'].'/convert', [
            'crm_role' => 'client',
        ], $headers)->assertOk()->json('data');

        $this->assertSame('client', $customer['crm_role']);
        $this->assertSame($account['id'], $customer['crm_account_id']);

        $this->getJson('/api/v1/customers/'.$customer['id'], $headers)
            ->assertOk()
            ->assertJsonPath('data.email', 'aline@maison.test');

        $stages = $this->getJson('/api/v1/crm/pipeline', $headers)->assertOk()->json('data');
        $won = collect($stages)->firstWhere('is_won', true);

        $opportunity = $this->postJson('/api/v1/crm/opportunities', [
            'title' => 'Contrat annuel',
            'customer_id' => $customer['id'],
            'crm_account_id' => $account['id'],
            'amount' => 150000,
        ], $headers)->assertCreated()->json('data');

        $this->patchJson('/api/v1/crm/opportunities/'.$opportunity['id'].'/stage', [
            'stage_id' => $won['id'],
        ], $headers)->assertOk()->assertJsonPath('data.status', 'won');

        $this->postJson('/api/v1/crm/activities', [
            'type' => 'call',
            'subject' => 'Relance',
            'customer_id' => $customer['id'],
            'direction' => 'outbound',
        ], $headers)->assertCreated();

        $campaign = $this->postJson('/api/v1/crm/campaigns', [
            'name' => 'Fidélité avril',
            'channel' => 'email',
            'status' => 'active',
        ], $headers)->assertCreated()->json('data');

        $this->postJson('/api/v1/crm/campaigns/'.$campaign['id'].'/members', [
            'customer_id' => $customer['id'],
        ], $headers)->assertCreated();

        $this->getJson('/api/v1/crm/customers/'.$customer['id'].'/dossier', $headers)
            ->assertOk()
            ->assertJsonPath('data.customer.id', $customer['id'])
            ->assertJsonPath('data.usage.crm', 2);

        $other = $this->createTenantFixture('crm-b', 'crm-b@test.local');
        $this->getJson('/api/v1/crm/customers/'.$customer['id'].'/dossier', $this->tenantHeaders($other['token'], $other['tenant']))
            ->assertNotFound();
        app(TenantContext::class)->bind($other['tenant']);
        $this->assertNull(Customer::query()->find($customer['id']));
    }
}
