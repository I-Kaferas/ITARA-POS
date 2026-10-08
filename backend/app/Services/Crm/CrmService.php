<?php

namespace App\Services\Crm;

use App\Enums\PartyContext;
use App\Enums\PartyKind;
use App\Models\CrmAccount;
use App\Models\CrmActivity;
use App\Models\CrmCampaign;
use App\Models\CrmCampaignMember;
use App\Models\CrmLead;
use App\Models\CrmOpportunity;
use App\Models\CrmPipelineStage;
use App\Models\Customer;
use App\Models\CustomerTransaction;
use App\Models\DeskDocument;
use App\Models\PosReservation;
use App\Models\Sale;
use App\Services\BusinessCore\PartyRegistry;
use App\Tenancy\TenantContext;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CrmService
{
    /** @var list<array{name: string, position: int, probability: int, is_won: bool, is_lost: bool}> */
    private const STAGES = [
        ['name' => 'Qualification', 'position' => 1, 'probability' => 10, 'is_won' => false, 'is_lost' => false],
        ['name' => 'Proposition', 'position' => 2, 'probability' => 40, 'is_won' => false, 'is_lost' => false],
        ['name' => 'Négociation', 'position' => 3, 'probability' => 70, 'is_won' => false, 'is_lost' => false],
        ['name' => 'Gagné', 'position' => 4, 'probability' => 100, 'is_won' => true, 'is_lost' => false],
        ['name' => 'Perdu', 'position' => 5, 'probability' => 0, 'is_won' => false, 'is_lost' => true],
    ];

    public function __construct(
        private readonly TenantContext $context,
        private readonly PartyRegistry $parties,
    ) {}

    /** @return \Illuminate\Support\Collection<int, CrmPipelineStage> */
    public function stages()
    {
        $tenantId = $this->context->requireId();
        if (CrmPipelineStage::query()->where('tenant_id', $tenantId)->doesntExist()) {
            foreach (self::STAGES as $stage) {
                CrmPipelineStage::query()->create([...$stage, 'tenant_id' => $tenantId]);
            }
        }

        return CrmPipelineStage::query()->orderBy('position')->get();
    }

    /** @param  array<string, mixed>  $data */
    public function createAccount(array $data): CrmAccount
    {
        $party = $this->parties->findOrCreate([
            'name' => $data['name'],
            'legal_name' => $data['legal_name'] ?? null,
            'email' => $data['email'] ?? null,
            'phone' => $data['phone'] ?? null,
            'tax_id' => $data['tax_id'] ?? null,
            'address' => $data['address'] ?? null,
        ], PartyKind::Organization);

        return $this->parties->ensureCrmAccount($party, $data);
    }

    /** @param  array<string, mixed>  $data */
    public function createParty(array $data, string $role): Customer
    {
        $this->assertAccount($data['crm_account_id'] ?? null);

        $party = $this->parties->findOrCreate([
            'name' => $data['name'],
            'company_name' => $data['company_name'] ?? null,
            'email' => $data['email'] ?? null,
            'phone' => $data['phone'] ?? null,
            'notes' => $data['notes'] ?? null,
        ]);

        return $this->parties->ensureCrmContact($party, [
            ...$data,
            'crm_role' => $role,
            'is_active' => $data['is_active'] ?? true,
        ], $role);
    }

    /** @param  array<string, mixed>  $data */
    public function createLead(array $data): CrmLead
    {
        $this->assertAccount($data['crm_account_id'] ?? null);

        return CrmLead::query()->create([
            ...$data,
            'tenant_id' => $this->context->requireId(),
            'source' => $data['source'] ?? 'manual',
            'status' => 'new',
        ]);
    }

    public function convertLead(CrmLead $lead, string $role = 'client'): Customer
    {
        if ($lead->status === 'converted' && $lead->customer_id) {
            $existing = Customer::query()->find($lead->customer_id);
            if ($existing) {
                return $existing;
            }
        }

        return DB::transaction(function () use ($lead, $role) {
            $customer = $lead->customer_id
                ? Customer::query()->find($lead->customer_id)
                : null;

            if (! $customer) {
                $customer = $this->createParty([
                    'name' => $lead->name,
                    'email' => $lead->email,
                    'phone' => $lead->phone,
                    'company_name' => $lead->company_name,
                    'crm_account_id' => $lead->crm_account_id,
                    'notes' => $lead->notes,
                ], $role);
            } else {
                $customer->crm_role = $role;
                $customer->save();
            }

            $lead->customer_id = $customer->id;
            $lead->status = 'converted';
            $lead->save();

            return $customer->fresh();
        });
    }

    /** @param  array<string, mixed>  $data */
    public function createOpportunity(array $data): CrmOpportunity
    {
        $this->assertCustomer($data['customer_id'] ?? null);
        $this->assertAccount($data['crm_account_id'] ?? null);
        $stage = isset($data['stage_id'])
            ? CrmPipelineStage::query()->findOrFail($data['stage_id'])
            : $this->stages()->first();

        $opportunity = CrmOpportunity::query()->create([
            'tenant_id' => $this->context->requireId(),
            'customer_id' => $data['customer_id'] ?? null,
            'crm_account_id' => $data['crm_account_id'] ?? null,
            'stage_id' => $stage->id,
            'title' => $data['title'],
            'amount' => $data['amount'] ?? 0,
            'expected_close_on' => $data['expected_close_on'] ?? null,
            'status' => $this->statusForStage($stage),
        ]);

        return $opportunity->load('stage');
    }

    public function moveOpportunity(CrmOpportunity $opportunity, string $stageId): CrmOpportunity
    {
        $stage = CrmPipelineStage::query()->findOrFail($stageId);
        $opportunity->stage_id = $stage->id;
        $opportunity->status = $this->statusForStage($stage);
        $opportunity->save();

        return $opportunity->fresh('stage');
    }

    /** @param  array<string, mixed>  $data */
    public function createActivity(array $data): CrmActivity
    {
        $this->assertCustomer($data['customer_id'] ?? null);
        $status = $data['status'] ?? ($data['type'] === 'note' ? 'done' : 'open');

        return CrmActivity::query()->create([
            ...$data,
            'tenant_id' => $this->context->requireId(),
            'status' => $status,
            'completed_at' => $status === 'done' ? ($data['completed_at'] ?? now()) : null,
        ]);
    }

    public function completeActivity(CrmActivity $activity): CrmActivity
    {
        $activity->status = 'done';
        $activity->completed_at = now();
        $activity->save();

        return $activity;
    }

    /** @param  array<string, mixed>  $data */
    public function createCampaign(array $data): CrmCampaign
    {
        return CrmCampaign::query()->create([
            ...$data,
            'tenant_id' => $this->context->requireId(),
            'channel' => $data['channel'] ?? 'email',
            'status' => $data['status'] ?? 'draft',
        ]);
    }

    public function addCampaignMember(CrmCampaign $campaign, string $customerId): CrmCampaignMember
    {
        $customer = Customer::query()->find($customerId);
        if (! $customer) {
            throw ValidationException::withMessages([
                'customer_id' => ['Customer was not found in this tenant.'],
            ]);
        }

        return CrmCampaignMember::query()->firstOrCreate(
            [
                'campaign_id' => $campaign->id,
                'customer_id' => $customer->id,
            ],
            [
                'tenant_id' => $this->context->requireId(),
                'status' => 'subscribed',
            ],
        );
    }

    /** @return array<string, mixed> */
    public function dossier(Customer $customer): array
    {
        $sales = Sale::query()->where('customer_id', $customer->id)->count();
        $reservations = PosReservation::query()->where('customer_id', $customer->id)->count();
        $invoices = CustomerTransaction::query()->where('customer_id', $customer->id)->count();
        $hotel = DeskDocument::query()
            ->where('kind', 'reservation')
            ->where('payload->customer_id', $customer->id)
            ->count();

        return [
            'customer' => $customer->load('account'),
            'loyalty' => [
                'points' => (int) $customer->loyalty_points,
                'tier' => $customer->loyalty_tier,
            ],
            'usage' => [
                'pos' => $sales,
                'restaurant' => $reservations,
                'hotel' => $hotel,
                'billing' => $invoices,
                'loyalty' => (int) $customer->loyalty_points,
                'crm' => CrmOpportunity::query()->where('customer_id', $customer->id)->count()
                    + CrmActivity::query()->where('customer_id', $customer->id)->count(),
            ],
            'opportunities' => CrmOpportunity::query()->with('stage')->where('customer_id', $customer->id)->latest()->limit(20)->get(),
            'activities' => CrmActivity::query()->where('customer_id', $customer->id)->latest()->limit(30)->get(),
            'campaigns' => CrmCampaignMember::query()->with('campaign')->where('customer_id', $customer->id)->get(),
        ];
    }

    /** @return array<string, int> */
    public function overview(): array
    {
        $this->stages();

        return [
            'prospects' => Customer::query()->where('crm_role', 'prospect')->count(),
            'clients' => Customer::query()->where('crm_role', 'client')->count(),
            'accounts' => CrmAccount::query()->count(),
            'contacts' => Customer::query()->whereNotNull('crm_account_id')->count(),
            'leads' => CrmLead::query()->where('status', '!=', 'converted')->count(),
            'opportunities' => CrmOpportunity::query()->where('status', 'open')->count(),
            'pipeline_amount' => (int) CrmOpportunity::query()->where('status', 'open')->sum('amount'),
            'tasks' => CrmActivity::query()->where('type', 'task')->where('status', 'open')->count(),
            'campaigns' => CrmCampaign::query()->count(),
        ];
    }

    private function assertCustomer(?string $id): void
    {
        if ($id && ! Customer::query()->whereKey($id)->exists()) {
            throw ValidationException::withMessages([
                'customer_id' => ['Customer was not found in this tenant.'],
            ]);
        }
    }

    private function assertAccount(?string $id): void
    {
        if ($id && ! CrmAccount::query()->whereKey($id)->exists()) {
            throw ValidationException::withMessages([
                'crm_account_id' => ['Account was not found in this tenant.'],
            ]);
        }
    }

    private function statusForStage(CrmPipelineStage $stage): string
    {
        if ($stage->is_won) {
            return 'won';
        }
        if ($stage->is_lost) {
            return 'lost';
        }

        return 'open';
    }
}
