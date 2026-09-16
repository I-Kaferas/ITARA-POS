<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PurchaseProforma;
use App\Models\PurchaseRequisition;
use App\Services\Purchase\PurchaseCycleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PurchaseCycleController extends Controller
{
    public function __construct(private readonly PurchaseCycleService $cycle) {}

    public function overview(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->cycle->overview([
                'from' => $request->string('from')->toString() ?: null,
                'to' => $request->string('to')->toString() ?: null,
                'supplier_id' => $request->string('supplier_id')->toString() ?: null,
                'warehouse_id' => $request->string('warehouse_id')->toString() ?: null,
            ]),
        ]);
    }

    public function requisitions(Request $request): JsonResponse
    {
        $query = PurchaseRequisition::query()
            ->with($this->cycle->requisitionRelations())
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }
        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->string('warehouse_id'));
        }
        if ($request->filled('supplier_id')) {
            $query->where('supplier_id', $request->string('supplier_id'));
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function storeRequisition(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
            'supplier_id' => ['nullable', 'uuid', 'exists:suppliers,id'],
            'branch_id' => ['nullable', 'uuid', 'exists:branches,id'],
            'priority' => ['nullable', Rule::in(['low', 'normal', 'high', 'urgent'])],
            'department' => ['nullable', 'string', 'max:100'],
            'needed_at' => ['nullable', 'date'],
            'reason' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_cost' => ['nullable', 'integer', 'min:0'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.tax_rate' => ['nullable', 'numeric', 'min:0'],
        ]);

        $requisition = $this->cycle->createRequisition($data, $data['items'], $request->user());

        return response()->json(['data' => $requisition], 201);
    }

    public function showRequisition(PurchaseRequisition $purchaseRequisition): JsonResponse
    {
        return response()->json([
            'data' => $purchaseRequisition->load($this->cycle->requisitionRelations()),
        ]);
    }

    public function actRequisition(Request $request, PurchaseRequisition $purchaseRequisition): JsonResponse
    {
        $data = $request->validate([
            'action' => ['required', 'string', Rule::in(['submit', 'approve', 'reject'])],
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);

        return response()->json([
            'data' => $this->cycle->actRequisition(
                $purchaseRequisition,
                $data['action'],
                $request->user(),
                $data['comment'] ?? null,
            ),
        ]);
    }

    public function convertRequisition(Request $request, PurchaseRequisition $purchaseRequisition): JsonResponse
    {
        $data = $request->validate([
            'target' => ['required', 'string', Rule::in(['proforma', 'purchase_order'])],
            'supplier_id' => ['nullable', 'uuid', 'exists:suppliers,id'],
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
        ]);

        return response()->json([
            'data' => $this->cycle->convertRequisition(
                $purchaseRequisition,
                $data['target'],
                $data['supplier_id'] ?? null,
                $data['warehouse_id'] ?? null,
                $request->user(),
            ),
        ], 201);
    }

    public function proformas(Request $request): JsonResponse
    {
        $query = PurchaseProforma::query()
            ->with($this->cycle->proformaRelations())
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }
        if ($request->filled('supplier_id')) {
            $query->where('supplier_id', $request->string('supplier_id'));
        }
        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->string('warehouse_id'));
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function storeProforma(Request $request): JsonResponse
    {
        $data = $request->validate([
            'supplier_id' => ['required', 'uuid', 'exists:suppliers,id'],
            'warehouse_id' => ['nullable', 'uuid', 'exists:warehouses,id'],
            'branch_id' => ['nullable', 'uuid', 'exists:branches,id'],
            'purchase_requisition_id' => ['nullable', 'uuid', 'exists:purchase_requisitions,id'],
            'payment_terms' => ['nullable', 'string', 'max:255'],
            'delivery_terms' => ['nullable', 'string', 'max:255'],
            'expires_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_cost' => ['nullable', 'integer', 'min:0'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.tax_rate' => ['nullable', 'numeric', 'min:0'],
        ]);

        $proforma = $this->cycle->createProforma($data, $data['items'], $request->user());

        return response()->json(['data' => $proforma], 201);
    }

    public function showProforma(PurchaseProforma $purchaseProforma): JsonResponse
    {
        return response()->json([
            'data' => $purchaseProforma->load($this->cycle->proformaRelations()),
        ]);
    }

    public function actProforma(Request $request, PurchaseProforma $purchaseProforma): JsonResponse
    {
        $data = $request->validate([
            'action' => ['required', 'string', Rule::in(['send', 'review', 'approve', 'reject'])],
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);

        return response()->json([
            'data' => $this->cycle->actProforma(
                $purchaseProforma,
                $data['action'],
                $request->user(),
                $data['comment'] ?? null,
            ),
        ]);
    }

    public function convertProforma(Request $request, PurchaseProforma $purchaseProforma): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
        ]);

        return response()->json([
            'data' => $this->cycle->convertProforma(
                $purchaseProforma,
                $data['warehouse_id'],
                $request->user(),
            ),
        ], 201);
    }

    public function returns(): JsonResponse
    {
        return response()->json(['data' => []]);
    }

    public function storeReturn(): JsonResponse
    {
        return response()->json([
            'message' => 'Les retours achats ne sont pas encore branchés.',
        ], 422);
    }

    public function showReturn(string $purchaseReturn): JsonResponse
    {
        return response()->json([
            'message' => 'Les retours achats ne sont pas encore branchés.',
        ], 404);
    }

    public function actReturn(string $purchaseReturn): JsonResponse
    {
        return response()->json([
            'message' => 'Les retours achats ne sont pas encore branchés.',
        ], 422);
    }
}
