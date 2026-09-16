<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\PurchaseOrderStatus;
use App\Http\Controllers\Controller;
use App\Models\PurchaseOrder;
use App\Models\Warehouse;
use App\Services\Purchase\GoodsReceiptService;
use App\Services\Purchase\PurchaseOrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PurchaseOrderController extends Controller
{
    public function __construct(
        private readonly PurchaseOrderService $purchaseOrderService,
        private readonly GoodsReceiptService $goodsReceiptService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = PurchaseOrder::query()
            ->with([
                'supplier:id,name,code',
                'warehouse:id,name,code',
                'requisition:id,number,status',
                'proforma:id,number,status',
            ])
            ->orderByDesc('created_at');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        if ($request->filled('supplier_id')) {
            $query->where('supplier_id', $request->string('supplier_id'));
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function show(PurchaseOrder $purchaseOrder): JsonResponse
    {
        return response()->json([
            'data' => $purchaseOrder->load([
                'items.product:id,sku,name',
                'supplier',
                'warehouse',
                'goodsReceipts.items.product:id,sku,name',
                'goodsReceipts.invoice:id,goods_receipt_id,invoice_number,status,total,paid_amount',
                'invoices.payments',
                'createdByUser:id,name',
                'approvedByUser:id,name',
                'requisition:id,number,status',
                'proforma:id,number,status',
            ]),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'warehouse_id' => ['required', 'uuid', 'exists:warehouses,id'],
            'supplier_id' => ['nullable', 'uuid', 'exists:suppliers,id'],
            'branch_id' => ['nullable', 'uuid', 'exists:branches,id'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'expected_at' => ['nullable', 'date'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_cost' => ['required', 'integer', 'min:0'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.tax_rate' => ['nullable', 'numeric', 'min:0'],
        ]);

        $warehouse = Warehouse::query()->findOrFail($data['warehouse_id']);

        $purchaseOrder = $this->purchaseOrderService->create(
            warehouse: $warehouse,
            items: $data['items'],
            supplierId: $data['supplier_id'] ?? null,
            branchId: $data['branch_id'] ?? null,
            createdBy: $request->user(),
            notes: $data['notes'] ?? null,
            expectedAt: isset($data['expected_at']) ? new \DateTimeImmutable($data['expected_at']) : null,
        );

        return response()->json(['data' => $purchaseOrder], 201);
    }

    public function update(Request $request, PurchaseOrder $purchaseOrder): JsonResponse
    {
        $data = $request->validate([
            'notes' => ['nullable', 'string', 'max:2000'],
            'expected_at' => ['nullable', 'date'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'uuid', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit_cost' => ['required', 'integer', 'min:0'],
            'items.*.product_variant_id' => ['nullable', 'uuid', 'exists:product_variants,id'],
            'items.*.tax_rate' => ['nullable', 'numeric', 'min:0'],
        ]);

        $purchaseOrder = $this->purchaseOrderService->update(
            purchaseOrder: $purchaseOrder,
            items: $data['items'],
            notes: $data['notes'] ?? null,
            expectedAt: isset($data['expected_at']) ? new \DateTimeImmutable($data['expected_at']) : null,
        );

        return response()->json(['data' => $purchaseOrder]);
    }

    public function confirm(Request $request, PurchaseOrder $purchaseOrder): JsonResponse
    {
        $purchaseOrder->load('items');

        if ($purchaseOrder->status === PurchaseOrderStatus::Draft) {
            return response()->json([
                'data' => $this->purchaseOrderService->submit($purchaseOrder),
            ]);
        }

        if ($purchaseOrder->status === PurchaseOrderStatus::Pending) {
            return response()->json([
                'data' => $this->purchaseOrderService->approve($purchaseOrder, $request->user())
                    ->fresh(['supplier:id,name,code', 'warehouse:id,name,code', 'items.product:id,sku,name']),
            ]);
        }

        return response()->json([
            'message' => 'Cet approvisionnement ne peut plus être confirmé.',
        ], 422);
    }

    public function submit(PurchaseOrder $purchaseOrder): JsonResponse
    {
        return response()->json([
            'data' => $this->purchaseOrderService->submit($purchaseOrder),
        ]);
    }

    public function approve(Request $request, PurchaseOrder $purchaseOrder): JsonResponse
    {
        return response()->json([
            'data' => $this->purchaseOrderService->approve($purchaseOrder, $request->user()),
        ]);
    }

    public function cancel(PurchaseOrder $purchaseOrder): JsonResponse
    {
        return response()->json([
            'data' => $this->purchaseOrderService->cancel($purchaseOrder),
        ]);
    }

    public function receive(Request $request, PurchaseOrder $purchaseOrder): JsonResponse
    {
        $data = $request->validate([
            'notes' => ['nullable', 'string', 'max:2000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.purchase_order_item_id' => ['required', 'uuid', 'exists:purchase_order_items,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.batch_id' => ['nullable', 'uuid', 'exists:batches,id'],
        ]);

        $receipt = $this->goodsReceiptService->receive(
            purchaseOrder: $purchaseOrder,
            items: $data['items'],
            receivedBy: $request->user(),
            notes: $data['notes'] ?? null,
        );

        return response()->json(['data' => $receipt], 201);
    }

    public function statuses(): JsonResponse
    {
        return response()->json([
            'data' => \App\Enums\PurchaseOrderStatus::values(),
        ]);
    }
}
