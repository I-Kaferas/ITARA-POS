<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\BranchExpense;
use App\Models\Company;
use App\Services\Organization\BranchProfileService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BranchController extends Controller
{
    public function __construct(private readonly BranchProfileService $profiles) {}

    public function index(Company $company): JsonResponse
    {
        return response()->json([
            'data' => $company->branches()->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request, Company $company): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:50'],
            'settings' => ['nullable', 'array'],
            'settings.timezone' => ['nullable', 'string', 'max:64'],
            'settings.receipt_footer' => ['nullable', 'string', 'max:500'],
            'is_active' => ['boolean'],
        ]);

        $branch = $company->branches()->create([
            ...$data,
            'tenant_id' => app('tenant.id'),
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json(['data' => $branch], 201);
    }

    public function show(Branch $branch): JsonResponse
    {
        return response()->json(['data' => $this->profiles->present($branch)]);
    }

    public function update(Request $request, Branch $branch): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'code' => ['sometimes', 'string', 'max:50'],
            'settings' => ['nullable', 'array'],
            'settings.timezone' => ['nullable', 'string', 'max:64'],
            'settings.receipt_footer' => ['nullable', 'string', 'max:500'],
            'is_active' => ['boolean'],
        ]);

        if (isset($data['settings']) && is_array($data['settings'])) {
            $data['settings'] = array_merge($branch->settings ?? [], $data['settings']);
        }

        $branch->update($data);

        return response()->json(['data' => $this->profiles->present($branch->fresh())]);
    }

    public function expenses(Branch $branch): JsonResponse
    {
        return response()->json([
            'data' => $branch->expenses()->latest('occurred_on')->limit(50)->get(),
        ]);
    }

    public function storeExpense(Request $request, Branch $branch): JsonResponse
    {
        $data = $request->validate([
            'store_id' => ['nullable', 'uuid'],
            'category' => ['nullable', 'string', 'max:80'],
            'description' => ['required', 'string', 'max:255'],
            'amount' => ['required', 'integer', 'min:1'],
            'currency_code' => ['nullable', 'string', 'size:3'],
            'occurred_on' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        if (! empty($data['store_id']) && ! $branch->stores()->whereKey($data['store_id'])->exists()) {
            return response()->json(['message' => 'Magasin hors de cette branche.'], 422);
        }

        $expense = BranchExpense::query()->create([
            ...$data,
            'tenant_id' => $branch->tenant_id,
            'branch_id' => $branch->id,
            'category' => $data['category'] ?? 'other',
            'currency_code' => strtoupper($data['currency_code'] ?? 'FBU'),
            'occurred_on' => $data['occurred_on'] ?? now()->toDateString(),
        ]);

        return response()->json(['data' => $expense], 201);
    }

    public function destroy(Branch $branch): JsonResponse
    {
        $branch->delete();

        return response()->json(['message' => 'Deleted.']);
    }
}
