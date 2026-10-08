<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\NumberingDocumentType;
use App\Enums\NumberingResetPolicy;
use App\Http\Controllers\Controller;
use App\Models\NumberingRule;
use App\Services\Numbering\ReferenceNumberGenerator;
use App\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class NumberingController extends Controller
{
    public function __construct(
        private readonly ReferenceNumberGenerator $numbering,
        private readonly TenantContext $tenants,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'branch_id' => ['nullable', 'uuid', 'exists:branches,id'],
        ]);

        $tenantId = $this->tenantId($request);

        $rules = NumberingRule::query()
            ->with(['branch:id,name,code'])
            ->where('tenant_id', $tenantId)
            ->when(
                ! empty($data['branch_id']),
                fn ($query) => $query->where(function ($inner) use ($data): void {
                    $inner->where('scope_key', NumberingRule::TENANT_SCOPE)
                        ->orWhere('branch_id', $data['branch_id']);
                }),
            )
            ->orderBy('document_type')
            ->orderBy('scope_key')
            ->get();

        return response()->json([
            'data' => [
                'catalog' => $this->numbering->catalog($tenantId, $data['branch_id'] ?? null),
                'rules' => $rules,
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $rule = $this->numbering->upsertRule($this->tenantId($request), $data);

        return response()->json(['data' => $rule], 201);
    }

    public function update(Request $request, NumberingRule $numberingRule): JsonResponse
    {
        $data = $this->validated($request, updating: true);

        if (array_key_exists('branch_id', $data) && $data['branch_id'] !== $numberingRule->branch_id) {
            // Changing scope is done via create; keep the rule identity stable.
            unset($data['branch_id']);
        }

        $numberingRule->fill([
            'prefix' => isset($data['prefix']) ? strtoupper(trim($data['prefix'])) : $numberingRule->prefix,
            'pattern' => $data['pattern'] ?? $numberingRule->pattern,
            'padding' => $data['padding'] ?? $numberingRule->padding,
            'reset_policy' => $data['reset_policy'] ?? $numberingRule->reset_policy,
            'starting_number' => $data['starting_number'] ?? $numberingRule->starting_number,
            'is_active' => $data['is_active'] ?? $numberingRule->is_active,
        ])->save();

        return response()->json([
            'data' => $numberingRule->fresh(['branch:id,name,code']),
        ]);
    }

    public function destroy(NumberingRule $numberingRule): JsonResponse
    {
        $numberingRule->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    public function preview(Request $request): JsonResponse
    {
        $data = $request->validate([
            'document_type' => ['required', 'string', Rule::in(NumberingDocumentType::values())],
            'branch_id' => ['nullable', 'uuid', 'exists:branches,id'],
            'at' => ['nullable', 'date'],
        ]);

        $reference = $this->numbering->preview(
            $data['document_type'],
            $this->tenantId($request),
            $data['branch_id'] ?? null,
            $data['at'] ?? null,
        );

        return response()->json([
            'data' => [
                'document_type' => $data['document_type'],
                'branch_id' => $data['branch_id'] ?? null,
                'reference' => $reference,
            ],
        ]);
    }

    /** @return array<string, mixed> */
    private function validated(Request $request, bool $updating = false): array
    {
        return $request->validate([
            'document_type' => [$updating ? 'sometimes' : 'required', 'string', Rule::in(NumberingDocumentType::values())],
            'branch_id' => ['nullable', 'uuid', 'exists:branches,id'],
            'prefix' => [$updating ? 'sometimes' : 'required', 'string', 'max:20', 'regex:/^[A-Za-z0-9_-]+$/'],
            'pattern' => ['nullable', 'string', 'max:80'],
            'padding' => ['nullable', 'integer', 'min:1', 'max:12'],
            'reset_policy' => ['nullable', 'string', Rule::in(NumberingResetPolicy::values())],
            'starting_number' => ['nullable', 'integer', 'min:1'],
            'is_active' => ['nullable', 'boolean'],
        ]);
    }

    private function tenantId(Request $request): string
    {
        $tenantId = $this->tenants->id() ?? $request->user()?->tenant_id;
        abort_if($tenantId === null, 403, 'Tenant required.');

        return (string) $tenantId;
    }
}
