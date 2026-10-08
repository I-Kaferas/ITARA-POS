<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\TaxComputationType;
use App\Enums\TaxKind;
use App\Http\Controllers\Controller;
use App\Models\SaleTax;
use App\Models\Tax;
use App\Models\TaxClass;
use App\Models\TaxGroup;
use App\Models\TaxRule;
use App\Services\Tax\TaxEngine;
use App\Services\Tax\TaxProfileInstaller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class TaxController extends Controller
{
    public function __construct(
        private readonly TaxEngine $engine,
        private readonly TaxProfileInstaller $profiles,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = Tax::query()->orderBy('priority')->orderBy('name');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validateTax($request);
        $tax = Tax::query()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'kind' => $data['kind'] ?? TaxKind::Vat->value,
            'type' => $data['type'] ?? TaxComputationType::Percentage->value,
            'priority' => $data['priority'] ?? 1,
            'is_inclusive' => $data['is_inclusive'] ?? false,
            'is_compound' => $data['is_compound'] ?? false,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $tax], 201);
    }

    public function show(Tax $tax): JsonResponse
    {
        return response()->json(['data' => $tax]);
    }

    public function update(Request $request, Tax $tax): JsonResponse
    {
        $data = $this->validateTax($request, partial: true);
        $tax->update($data);

        return response()->json(['data' => $tax->fresh()]);
    }

    public function destroy(Tax $tax): JsonResponse
    {
        $tax->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    public function calculate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:0'],
            'amount_is_inclusive' => ['boolean'],
            'tax_ids' => ['nullable', 'array'],
            'tax_ids.*' => ['uuid'],
            'tax_group_id' => ['nullable', 'uuid'],
            'tax_class_id' => ['nullable', 'uuid'],
            'country' => ['nullable', 'string', 'size:2'],
            'region' => ['nullable', 'string', 'max:120'],
        ]);

        $result = $this->engine->calculate(
            amount: (int) $data['amount'],
            amountIsInclusive: (bool) ($data['amount_is_inclusive'] ?? false),
            taxIds: $data['tax_ids'] ?? null,
            taxGroupId: $data['tax_group_id'] ?? null,
            taxClassId: $data['tax_class_id'] ?? null,
            country: isset($data['country']) ? strtoupper($data['country']) : null,
            region: $data['region'] ?? null,
        );

        return response()->json(['data' => $result]);
    }

    public function report(Request $request): JsonResponse
    {
        [$from, $to] = $this->period($request);

        $rows = SaleTax::query()
            ->whereHas('sale', function ($query) use ($from, $to) {
                $query->whereBetween('created_at', [$from, $to]);
            })
            ->selectRaw('tax_id, tax_name as name, tax_rate as rate, count(*) as lines, coalesce(sum(taxable_amount),0) as taxable_amount, coalesce(sum(tax_amount),0) as tax_amount')
            ->groupBy('tax_id', 'tax_name', 'tax_rate')
            ->orderBy('tax_name')
            ->get();

        $taxes = Tax::query()->whereIn('id', $rows->pluck('tax_id')->filter()->all())->get()->keyBy('id');

        $summary = $rows->map(function ($row) use ($taxes) {
            $tax = $row->tax_id ? $taxes->get($row->tax_id) : null;

            return [
                'tax_id' => $row->tax_id,
                'code' => $tax?->code,
                'name' => $row->name ?: $tax?->name,
                'rate' => (float) $row->rate,
                'lines' => (int) $row->lines,
                'taxable_amount' => (int) $row->taxable_amount,
                'tax_amount' => (int) $row->tax_amount,
            ];
        })->values();

        return response()->json([
            'data' => [
                'summary' => $summary,
                'taxable_amount' => (int) $summary->sum('taxable_amount'),
                'tax_amount' => (int) $summary->sum('tax_amount'),
                'lines' => (int) $summary->sum('lines'),
            ],
        ]);
    }

    public function register(Request $request): JsonResponse
    {
        [$from, $to] = $this->period($request);

        $rows = SaleTax::query()
            ->with(['sale:id,reference,created_at'])
            ->whereHas('sale', function ($query) use ($from, $to) {
                $query->whereBetween('created_at', [$from, $to]);
            })
            ->orderByDesc('created_at')
            ->limit(500)
            ->get();

        $taxes = Tax::query()
            ->whereIn('id', $rows->pluck('tax_id')->filter()->unique()->all())
            ->get()
            ->keyBy('id');

        $payload = $rows->map(function (SaleTax $row) use ($taxes) {
            $tax = $row->tax_id ? $taxes->get($row->tax_id) : null;

            return [
                'id' => $row->id,
                'sale_id' => $row->sale_id,
                'reference' => $row->sale?->reference,
                'occurred_at' => optional($row->sale?->created_at)?->toIso8601String(),
                'tax_id' => $row->tax_id,
                'code' => $tax?->code,
                'name' => $row->tax_name ?: $tax?->name,
                'rate' => (float) $row->tax_rate,
                'taxable_amount' => (int) $row->taxable_amount,
                'tax_amount' => (int) $row->tax_amount,
            ];
        });

        return response()->json(['data' => $payload]);
    }

    public function groups(): JsonResponse
    {
        $groups = TaxGroup::query()
            ->with(['taxes' => fn ($q) => $q->orderBy('priority')->orderBy('name')])
            ->orderBy('name')
            ->get();

        return response()->json(['data' => $groups]);
    }

    public function storeGroup(Request $request): JsonResponse
    {
        $data = $this->validateGroup($request);
        $group = TaxGroup::query()->create([
            ...collect($data)->except('tax_ids')->all(),
            'tenant_id' => app('tenant.id'),
            'is_active' => $data['is_active'] ?? true,
        ]);
        $this->syncGroupTaxes($group, $data['tax_ids'] ?? []);

        return response()->json(['data' => $group->load('taxes')], 201);
    }

    public function updateGroup(Request $request, TaxGroup $taxGroup): JsonResponse
    {
        $data = $this->validateGroup($request, partial: true);
        $taxGroup->update(collect($data)->except('tax_ids')->all());
        if (array_key_exists('tax_ids', $data)) {
            $this->syncGroupTaxes($taxGroup, $data['tax_ids'] ?? []);
        }

        return response()->json(['data' => $taxGroup->fresh()->load('taxes')]);
    }

    public function destroyGroup(TaxGroup $taxGroup): JsonResponse
    {
        $taxGroup->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    public function classes(): JsonResponse
    {
        return response()->json([
            'data' => TaxClass::query()->orderBy('name')->get(),
        ]);
    }

    public function storeClass(Request $request): JsonResponse
    {
        $data = $this->validateClass($request);
        $class = TaxClass::query()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $class], 201);
    }

    public function updateClass(Request $request, TaxClass $taxClass): JsonResponse
    {
        $data = $this->validateClass($request, partial: true);
        $taxClass->update($data);

        return response()->json(['data' => $taxClass->fresh()]);
    }

    public function destroyClass(TaxClass $taxClass): JsonResponse
    {
        $taxClass->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    public function rules(): JsonResponse
    {
        $rules = TaxRule::query()
            ->with(['taxClass:id,name,code', 'tax:id,name,code', 'taxGroup:id,name,code'])
            ->orderBy('priority')
            ->orderBy('name')
            ->get();

        return response()->json(['data' => $rules]);
    }

    public function storeRule(Request $request): JsonResponse
    {
        $data = $this->validateRule($request);
        $rule = TaxRule::query()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'priority' => $data['priority'] ?? 1,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json([
            'data' => $rule->load(['taxClass:id,name,code', 'tax:id,name,code', 'taxGroup:id,name,code']),
        ], 201);
    }

    public function updateRule(Request $request, TaxRule $taxRule): JsonResponse
    {
        $data = $this->validateRule($request, partial: true);
        $taxRule->update($data);

        return response()->json([
            'data' => $taxRule->fresh()->load(['taxClass:id,name,code', 'tax:id,name,code', 'taxGroup:id,name,code']),
        ]);
    }

    public function destroyRule(TaxRule $taxRule): JsonResponse
    {
        $taxRule->delete();

        return response()->json(['message' => 'Deleted.']);
    }

    public function profiles(): JsonResponse
    {
        return response()->json(['data' => $this->profiles->availableProfiles()]);
    }

    public function applyProfile(Request $request): JsonResponse
    {
        $data = $request->validate([
            'profile' => ['required', 'string', Rule::in(array_keys(config('tax_profiles.profiles', [])))],
        ]);

        $result = $this->profiles->install((string) app('tenant.id'), $data['profile']);

        return response()->json(['data' => $result]);
    }

    /** @return array{0: Carbon, 1: Carbon} */
    private function period(Request $request): array
    {
        $data = $request->validate([
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
        ]);

        $from = isset($data['from'])
            ? Carbon::parse($data['from'])->startOfDay()
            : now()->startOfMonth();
        $to = isset($data['to'])
            ? Carbon::parse($data['to'])->endOfDay()
            : now()->endOfDay();

        return [$from, $to];
    }

    /** @return array<string, mixed> */
    private function validateTax(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        $data = $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'code' => [$required, 'string', 'max:50'],
            'kind' => ['sometimes', 'string', Rule::in(TaxKind::values())],
            'type' => ['sometimes', 'string', Rule::in(TaxComputationType::values())],
            'rate' => [$required, 'numeric', 'min:0', 'max:100'],
            'priority' => ['sometimes', 'integer', 'min:1'],
            'country' => ['nullable', 'string', 'size:2'],
            'region' => ['nullable', 'string', 'max:120'],
            'is_inclusive' => ['boolean'],
            'is_compound' => ['boolean'],
            'is_active' => ['boolean'],
            'description' => ['nullable', 'string'],
        ]);

        if (isset($data['country'])) {
            $data['country'] = $data['country'] ? strtoupper($data['country']) : null;
        }
        if (array_key_exists('kind', $data) && in_array($data['kind'], [TaxKind::Exempt->value, TaxKind::ZeroRated->value], true)) {
            $data['rate'] = 0;
        }

        return $data;
    }

    /** @return array<string, mixed> */
    private function validateGroup(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'code' => [$required, 'string', 'max:50'],
            'description' => ['nullable', 'string'],
            'is_active' => ['boolean'],
            'tax_ids' => ['nullable', 'array'],
            'tax_ids.*' => ['uuid', Rule::exists('taxes', 'id')],
        ]);
    }

    /** @return array<string, mixed> */
    private function validateClass(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'code' => [$required, 'string', 'max:50'],
            'description' => ['nullable', 'string'],
            'is_active' => ['boolean'],
        ]);
    }

    /** @return array<string, mixed> */
    private function validateRule(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        $data = $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'tax_class_id' => ['nullable', 'uuid', Rule::exists('tax_classes', 'id')],
            'tax_id' => ['nullable', 'uuid', Rule::exists('taxes', 'id')],
            'tax_group_id' => ['nullable', 'uuid', Rule::exists('tax_groups', 'id')],
            'country' => ['nullable', 'string', 'size:2'],
            'region' => ['nullable', 'string', 'max:120'],
            'priority' => ['sometimes', 'integer', 'min:1'],
            'is_active' => ['boolean'],
            'description' => ['nullable', 'string'],
        ]);

        if (isset($data['country'])) {
            $data['country'] = $data['country'] ? strtoupper($data['country']) : null;
        }

        return $data;
    }

    /** @param  list<string>  $taxIds */
    private function syncGroupTaxes(TaxGroup $group, array $taxIds): void
    {
        $sync = [];
        foreach (array_values($taxIds) as $index => $taxId) {
            $sync[$taxId] = ['id' => (string) Str::uuid(), 'sort_order' => $index];
        }
        $group->taxes()->sync($sync);
    }
}
