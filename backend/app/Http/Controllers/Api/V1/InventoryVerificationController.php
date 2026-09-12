<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\InventoryVerificationFinding;
use App\Models\InventoryVerificationPlan;
use App\Models\InventoryVerificationRun;
use App\Models\Warehouse;
use App\Services\Inventory\InventoryVerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class InventoryVerificationController extends Controller
{
    public function __construct(
        private readonly InventoryVerificationService $verificationService,
    ) {}

    public function dashboard(Request $request): JsonResponse
    {
        $data = $request->validate(['warehouse_id' => ['required', 'uuid', 'exists:warehouses,id']]);

        return response()->json([
            'data' => $this->verificationService->dashboard(Warehouse::query()->findOrFail($data['warehouse_id'])),
        ]);
    }

    public function suggestions(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'category_id' => ['nullable', 'uuid'],
            'inventory_class' => ['nullable', 'string', Rule::in(['A', 'B', 'C'])],
        ]);

        return response()->json([
            'data' => $this->verificationService->suggest(
                Warehouse::query()->findOrFail($data['warehouse_id']),
                $data['category_id'] ?? null,
                $data['inventory_class'] ?? null,
            ),
        ]);
    }

    public function plans(Request $request): JsonResponse
    {
        $query = InventoryVerificationPlan::query()->with(['warehouse:id,name', 'responsible:id,name'])->orderBy('name');
        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->string('warehouse_id'));
        }

        return response()->json(['data' => $query->get()]);
    }

    public function storePlan(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'category_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'inventory_class' => ['nullable', 'string', Rule::in(['A', 'B', 'C'])],
            'frequency' => ['required', 'string', Rule::in(['daily', 'weekly', 'monthly', 'quarterly'])],
            'responsible_id' => ['nullable', 'uuid', 'exists:users,id'],
            'next_run_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        return response()->json([
            'data' => $this->verificationService->createPlan(
                Warehouse::query()->findOrFail($data['warehouse_id']),
                $request->user(),
                $data,
            ),
        ], 201);
    }

    public function run(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'plan_id' => ['nullable', 'uuid', 'exists:inventory_verification_plans,id'],
            'product_ids' => ['nullable', 'array'],
            'product_ids.*' => ['uuid'],
        ]);
        $plan = isset($data['plan_id']) ? InventoryVerificationPlan::query()->find($data['plan_id']) : null;

        return response()->json([
            'data' => $this->verificationService->run(
                $plan,
                Warehouse::query()->findOrFail($data['warehouse_id']),
                $request->user(),
                $data['product_ids'] ?? [],
            ),
        ], 201);
    }

    public function show(InventoryVerificationRun $inventoryVerificationRun): JsonResponse
    {
        return response()->json([
            'data' => $inventoryVerificationRun->load([
                'plan:id,name',
                'warehouse:id,name',
                'performedBy:id,name',
                'validatedBy:id,name',
                'findings.product:id,name,sku',
            ]),
        ]);
    }

    public function runs(Request $request): JsonResponse
    {
        $query = InventoryVerificationRun::query()
            ->with(['warehouse:id,name', 'performedBy:id,name'])
            ->withCount('findings')
            ->orderByDesc('created_at');
        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->string('warehouse_id'));
        }

        return response()->json(['data' => $query->limit(30)->get()]);
    }

    public function resolve(Request $request, InventoryVerificationFinding $inventoryVerificationFinding): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'string', Rule::in(['justified', 'corrected', 'validated'])],
            'note' => ['nullable', 'string', 'max:1000'],
            'action_taken' => ['nullable', 'string', 'max:80'],
        ]);

        return response()->json([
            'data' => $this->verificationService->resolveFinding(
                $inventoryVerificationFinding,
                $request->user(),
                $data['status'],
                $data['note'] ?? null,
                $data['action_taken'] ?? null,
            ),
        ]);
    }

    public function validateRun(Request $request, InventoryVerificationRun $inventoryVerificationRun): JsonResponse
    {
        return response()->json([
            'data' => $this->verificationService->validateRun($inventoryVerificationRun, $request->user()),
        ]);
    }
}
