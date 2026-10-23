<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PosTable;
use App\Models\QrOrder;
use App\Models\Store;
use App\Models\TableQrToken;
use App\Models\User;
use App\Services\Qr\QrOrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class QrOrderingController extends Controller
{
    public function __construct(private readonly QrOrderService $orders) {}

    public function tokens(Store $store): JsonResponse
    {
        return response()->json([
            'data' => [
                'approval_mode' => $store->qr_approval_mode ?: 'manual',
                'tables' => $this->orders->tokensForStore($store),
            ],
        ]);
    }

    public function issue(Store $store, PosTable $posTable): JsonResponse
    {
        $this->sameStore($store, $posTable);
        $token = $this->orders->issueToken($posTable, rotate: false);

        return response()->json(['data' => $this->tokenPayload($token)], 201);
    }

    public function rotate(Store $store, PosTable $posTable): JsonResponse
    {
        $this->sameStore($store, $posTable);
        $token = $this->orders->issueToken($posTable, rotate: true);

        return response()->json(['data' => $this->tokenPayload($token)]);
    }

    public function toggle(Request $request, TableQrToken $tableQrToken): JsonResponse
    {
        $data = $request->validate([
            'active' => ['required', 'boolean'],
        ]);
        $token = $this->orders->setTokenActive($tableQrToken, (bool) $data['active']);

        return response()->json(['data' => $this->tokenPayload($token)]);
    }

    public function svg(TableQrToken $tableQrToken): Response
    {
        return response($this->orders->svg($tableQrToken), 200, [
            'Content-Type' => 'image/svg+xml',
            'Content-Disposition' => 'inline; filename="table-'.$tableQrToken->pos_table_id.'.svg"',
        ]);
    }

    public function settings(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'mode' => ['required', 'in:manual,automatic'],
        ]);
        $store = $this->orders->setApprovalMode($store, $data['mode']);

        return response()->json(['data' => ['approval_mode' => $store->qr_approval_mode]]);
    }

    public function index(Request $request, Store $store): JsonResponse
    {
        $status = $request->query('status');

        return response()->json([
            'data' => [
                'pending_count' => $this->orders->pendingCount($store),
                'approval_mode' => $store->qr_approval_mode ?: 'manual',
                'orders' => $this->orders->listForCashier($store, is_string($status) ? $status : null),
            ],
        ]);
    }

    public function approve(QrOrder $qrOrder): JsonResponse
    {
        $order = $this->orders->approve($qrOrder, $this->actor());

        return response()->json([
            'data' => $this->orders->presentCashier($order->load('table', 'approver')),
        ]);
    }

    public function reject(Request $request, QrOrder $qrOrder): JsonResponse
    {
        $data = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);
        $order = $this->orders->reject($qrOrder, $this->actor(), $data['reason']);

        return response()->json(['data' => $this->orders->presentCashier($order)]);
    }

    public function update(Request $request, QrOrder $qrOrder): JsonResponse
    {
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1', 'max:40'],
            'items.*.product_id' => ['required', 'uuid'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:20'],
            'items.*.note' => ['nullable', 'string', 'max:200'],
            'items.*.variant_id' => ['nullable', 'uuid'],
            'items.*.sale_unit_id' => ['nullable', 'uuid'],
            'items.*.side_ids' => ['nullable', 'array'],
            'items.*.side_ids.*' => ['uuid'],
            'items.*.extras' => ['nullable', 'array'],
            'items.*.extras.*.product_id' => ['required', 'uuid'],
            'items.*.extras.*.quantity' => ['nullable', 'integer', 'min:1', 'max:20'],
        ]);
        $order = $this->orders->updateByCashier($qrOrder, $this->actor(), $data['items']);

        return response()->json(['data' => $this->orders->presentCashier($order)]);
    }

    public function approveAll(Store $store): JsonResponse
    {
        $count = $this->orders->approveAll($store, $this->actor());

        return response()->json(['data' => ['approved' => $count]]);
    }

    private function sameStore(Store $store, PosTable $table): void
    {
        if ($table->store_id !== $store->id) {
            abort(404);
        }
    }

    private function actor(): User
    {
        $user = auth()->user();
        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }

    /** @return array<string, mixed> */
    private function tokenPayload(TableQrToken $token): array
    {
        $token->loadMissing('table:id,name,code');

        return [
            'id' => $token->id,
            'table_id' => $token->pos_table_id,
            'table' => $token->table?->only(['id', 'name', 'code']),
            'active' => $token->is_active,
            'order_url' => $this->orders->orderUrl($token),
        ];
    }
}
