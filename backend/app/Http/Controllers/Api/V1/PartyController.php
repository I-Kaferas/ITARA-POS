<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\PartyContext;
use App\Enums\PartyKind;
use App\Http\Controllers\Controller;
use App\Models\Party;
use App\Services\BusinessCore\BusinessCore;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PartyController extends Controller
{
    public function __construct(private readonly BusinessCore $core) {}

    public function index(Request $request): JsonResponse
    {
        $query = Party::query()
            ->with(['customer', 'supplier', 'employee', 'contexts'])
            ->orderBy('display_name');

        if ($request->filled('kind')) {
            $query->where('kind', $request->string('kind'));
        }

        if ($search = $request->string('search')->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('display_name', 'like', "%{$search}%")
                    ->orWhere('legal_name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('code', 'like', "%{$search}%")
                    ->orWhere('tax_id', 'like', "%{$search}%");
            });
        }

        if ($context = $request->string('context')->toString()) {
            $query->whereHas('contexts', fn ($q) => $q->where('context', $context)->where('is_active', true));
        }

        if ($role = $request->string('role')->toString()) {
            match ($role) {
                'customer' => $query->whereHas('customer'),
                'supplier' => $query->whereHas('supplier'),
                'employee' => $query->whereHas('employee'),
                default => null,
            };
        }

        return response()->json(['data' => $query->paginate($request->pageSize())]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'kind' => ['nullable', Rule::in(PartyKind::values())],
            'display_name' => ['required', 'string', 'max:255'],
            'legal_name' => ['nullable', 'string', 'max:255'],
            'code' => ['nullable', 'string', 'max:50'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'address' => ['nullable', 'array'],
            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'is_active' => ['boolean'],
            'roles' => ['nullable', 'array'],
            'roles.*' => ['string', Rule::in(['customer', 'supplier', 'employee', 'crm'])],
            'contexts' => ['nullable', 'array'],
            'contexts.*' => ['string', Rule::in(PartyContext::values())],
            'crm_role' => ['nullable', Rule::in(['prospect', 'client'])],
            'crm_account_id' => ['nullable', 'uuid', 'exists:crm_accounts,id'],
            'job_title' => ['nullable', 'string', 'max:120'],
        ]);

        $kind = PartyKind::tryFrom($data['kind'] ?? '') ?? PartyKind::Person;
        $party = $this->core->parties->findOrCreate([
            ...$data,
            'name' => $data['display_name'],
        ], $kind);

        $roles = $data['roles'] ?? ['customer'];
        foreach ($roles as $role) {
            match ($role) {
                'customer' => $this->core->parties->ensureCustomer($party, [
                    'crm_role' => $data['crm_role'] ?? 'client',
                    'crm_account_id' => $data['crm_account_id'] ?? null,
                    'job_title' => $data['job_title'] ?? null,
                ], PartyContext::Pos),
                'supplier' => $this->core->parties->ensureSupplier($party),
                'employee' => $this->core->parties->ensureEmployee($party, [
                    'job_title' => $data['job_title'] ?? null,
                ]),
                'crm' => $this->core->parties->ensureCrmContact($party, [
                    'crm_account_id' => $data['crm_account_id'] ?? null,
                    'job_title' => $data['job_title'] ?? null,
                ], $data['crm_role'] ?? 'client'),
                default => null,
            };
        }

        foreach ($data['contexts'] ?? [] as $context) {
            $enum = PartyContext::tryFrom($context);
            if ($enum) {
                $this->core->parties->attachContext($party, $enum);
            }
        }

        return response()->json(['data' => $this->core->parties->dossier($party->fresh())], 201);
    }

    public function show(Party $party): JsonResponse
    {
        return response()->json(['data' => $this->core->parties->dossier($party)]);
    }

    public function attachRole(Request $request, Party $party): JsonResponse
    {
        $data = $request->validate([
            'role' => ['required', Rule::in(['customer', 'supplier', 'employee', 'crm'])],
            'context' => ['nullable', Rule::in(PartyContext::values())],
            'crm_role' => ['nullable', Rule::in(['prospect', 'client'])],
            'crm_account_id' => ['nullable', 'uuid', 'exists:crm_accounts,id'],
            'job_title' => ['nullable', 'string', 'max:120'],
            'department' => ['nullable', 'string', 'max:120'],
            'user_id' => ['nullable', 'uuid', 'exists:users,id'],
        ]);

        match ($data['role']) {
            'customer' => $this->core->parties->ensureCustomer($party, $data, PartyContext::tryFrom($data['context'] ?? '') ?? PartyContext::Pos),
            'supplier' => $this->core->parties->ensureSupplier($party, $data),
            'employee' => $this->core->parties->ensureEmployee($party, $data),
            'crm' => $this->core->parties->ensureCrmContact($party, $data, $data['crm_role'] ?? 'client'),
            default => null,
        };

        if (! empty($data['context'])) {
            $enum = PartyContext::tryFrom($data['context']);
            if ($enum) {
                $this->core->parties->attachContext($party, $enum);
            }
        }

        return response()->json(['data' => $this->core->parties->dossier($party->fresh())]);
    }

    public function attachContext(Request $request, Party $party): JsonResponse
    {
        $data = $request->validate([
            'context' => ['required', Rule::in(PartyContext::values())],
            'label' => ['nullable', 'string', 'max:120'],
            'metadata' => ['nullable', 'array'],
        ]);

        $link = $this->core->parties->attachContext(
            $party,
            PartyContext::from($data['context']),
            $data['label'] ?? null,
            $data['metadata'] ?? [],
        );

        return response()->json(['data' => $link], 201);
    }

    public function entities(): JsonResponse
    {
        return response()->json(['data' => $this->core->entities()]);
    }
}
