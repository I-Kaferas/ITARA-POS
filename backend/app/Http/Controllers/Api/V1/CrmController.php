<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CrmAccount;
use App\Models\CrmActivity;
use App\Models\CrmCampaign;
use App\Models\CrmLead;
use App\Models\CrmOpportunity;
use App\Models\Customer;
use App\Services\Crm\CrmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CrmController extends Controller
{
    public function __construct(private readonly CrmService $crm) {}

    public function overview(): JsonResponse
    {
        return response()->json(['data' => $this->crm->overview()]);
    }

    public function pipeline(): JsonResponse
    {
        $stages = $this->crm->stages()->load(['opportunities.customer', 'opportunities.account']);

        return response()->json(['data' => $stages]);
    }

    public function accounts(Request $request): JsonResponse
    {
        $query = CrmAccount::query()->withCount('contacts')->orderBy('name');
        $this->search($query, $request, ['name', 'legal_name', 'email', 'phone']);

        return response()->json(['data' => $query->limit(100)->get()]);
    }

    public function storeAccount(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'legal_name' => ['nullable', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'website' => ['nullable', 'string', 'max:255'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'industry' => ['nullable', 'string', 'max:80'],
        ]);

        return response()->json(['data' => $this->crm->createAccount($data)], 201);
    }

    public function parties(Request $request): JsonResponse
    {
        $role = $request->string('role')->toString();
        $query = Customer::query()->with('account')->orderBy('name');
        if (in_array($role, ['prospect', 'client'], true)) {
            $query->where('crm_role', $role);
        }
        if ($request->boolean('contacts')) {
            $query->whereNotNull('crm_account_id');
        }
        $this->search($query, $request, ['name', 'code', 'email', 'phone', 'company_name']);

        return response()->json(['data' => $query->limit(100)->get()]);
    }

    public function storeParty(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'company_name' => ['nullable', 'string', 'max:255'],
            'job_title' => ['nullable', 'string', 'max:120'],
            'crm_account_id' => ['nullable', 'uuid', 'exists:crm_accounts,id'],
            'crm_role' => ['required', Rule::in(['prospect', 'client'])],
            'notes' => ['nullable', 'string'],
        ]);
        $role = $data['crm_role'];
        unset($data['crm_role']);

        return response()->json(['data' => $this->crm->createParty($data, $role)], 201);
    }

    public function leads(Request $request): JsonResponse
    {
        $query = CrmLead::query()->with('customer')->latest();
        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json(['data' => $query->limit(100)->get()]);
    }

    public function storeLead(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'company_name' => ['nullable', 'string', 'max:255'],
            'source' => ['nullable', 'string', 'max:40'],
            'crm_account_id' => ['nullable', 'uuid', 'exists:crm_accounts,id'],
            'notes' => ['nullable', 'string'],
        ]);

        return response()->json(['data' => $this->crm->createLead($data)], 201);
    }

    public function convertLead(Request $request, CrmLead $lead): JsonResponse
    {
        $data = $request->validate([
            'crm_role' => ['nullable', Rule::in(['prospect', 'client'])],
        ]);

        return response()->json([
            'data' => $this->crm->convertLead($lead, $data['crm_role'] ?? 'client'),
        ]);
    }

    public function opportunities(): JsonResponse
    {
        return response()->json([
            'data' => CrmOpportunity::query()->with(['stage', 'customer', 'account'])->latest()->limit(100)->get(),
        ]);
    }

    public function storeOpportunity(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'crm_account_id' => ['nullable', 'uuid', 'exists:crm_accounts,id'],
            'stage_id' => ['nullable', 'uuid', 'exists:crm_pipeline_stages,id'],
            'amount' => ['nullable', 'integer', 'min:0'],
            'expected_close_on' => ['nullable', 'date'],
        ]);

        return response()->json(['data' => $this->crm->createOpportunity($data)], 201);
    }

    public function moveOpportunity(Request $request, CrmOpportunity $opportunity): JsonResponse
    {
        $data = $request->validate([
            'stage_id' => ['required', 'uuid', 'exists:crm_pipeline_stages,id'],
        ]);

        return response()->json(['data' => $this->crm->moveOpportunity($opportunity, $data['stage_id'])]);
    }

    public function activities(Request $request): JsonResponse
    {
        $query = CrmActivity::query()->with('customer')->latest();
        if ($request->filled('type')) {
            $query->where('type', $request->string('type'));
        }
        if ($request->filled('customer_id')) {
            $query->where('customer_id', $request->string('customer_id'));
        }

        return response()->json(['data' => $query->limit(100)->get()]);
    }

    public function storeActivity(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(['call', 'email', 'note', 'task'])],
            'subject' => ['required', 'string', 'max:255'],
            'body' => ['nullable', 'string'],
            'direction' => ['nullable', Rule::in(['inbound', 'outbound'])],
            'customer_id' => ['nullable', 'uuid', 'exists:customers,id'],
            'lead_id' => ['nullable', 'uuid', 'exists:crm_leads,id'],
            'opportunity_id' => ['nullable', 'uuid', 'exists:crm_opportunities,id'],
            'due_at' => ['nullable', 'date'],
            'status' => ['nullable', Rule::in(['open', 'done'])],
        ]);

        return response()->json(['data' => $this->crm->createActivity($data)], 201);
    }

    public function completeActivity(CrmActivity $activity): JsonResponse
    {
        return response()->json(['data' => $this->crm->completeActivity($activity)]);
    }

    public function campaigns(): JsonResponse
    {
        return response()->json([
            'data' => CrmCampaign::query()->withCount('members')->latest()->limit(100)->get(),
        ]);
    }

    public function storeCampaign(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'channel' => ['nullable', Rule::in(['email', 'sms', 'pos'])],
            'status' => ['nullable', Rule::in(['draft', 'active', 'closed'])],
            'starts_on' => ['nullable', 'date'],
            'ends_on' => ['nullable', 'date'],
        ]);

        return response()->json(['data' => $this->crm->createCampaign($data)], 201);
    }

    public function addMember(Request $request, CrmCampaign $campaign): JsonResponse
    {
        $data = $request->validate([
            'customer_id' => ['required', 'uuid'],
        ]);

        return response()->json(['data' => $this->crm->addCampaignMember($campaign, $data['customer_id'])], 201);
    }

    public function dossier(Customer $customer): JsonResponse
    {
        return response()->json(['data' => $this->crm->dossier($customer)]);
    }

    /** @param  list<string>  $columns */
    private function search($query, Request $request, array $columns): void
    {
        $term = trim($request->string('q')->toString());
        if ($term === '') {
            return;
        }
        $query->where(function ($inner) use ($columns, $term) {
            foreach ($columns as $column) {
                $inner->orWhere($column, 'like', '%'.$term.'%');
            }
        });
    }
}
