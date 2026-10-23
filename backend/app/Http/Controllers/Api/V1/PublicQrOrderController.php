<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Qr\QrOrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PublicQrOrderController extends Controller
{
    public function __construct(private readonly QrOrderService $orders) {}

    public function show(string $token): JsonResponse
    {
        $row = $this->orders->findToken($token);
        if ($row === null || ! $row->is_active) {
            return response()->json([
                'message' => 'Ce QR code est invalide ou désactivé.',
            ], 404);
        }

        return response()->json(['data' => $this->orders->menu($row)]);
    }

    public function store(Request $request, string $token): JsonResponse
    {
        $row = $this->activeToken($token);
        $data = $request->validate([
            'idempotency_key' => ['required', 'string', 'max:80'],
            'locale' => ['nullable', 'string', 'max:5'],
            'items' => ['required', 'array', 'min:1', 'max:40'],
            'items.*.product_id' => ['required', 'uuid'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:20'],
            'items.*.note' => ['nullable', 'string', 'max:200'],
            'items.*.variant_id' => ['nullable', 'uuid'],
            'items.*.sale_unit_id' => ['nullable', 'uuid'],
            'items.*.side_ids' => ['nullable', 'array', 'max:12'],
            'items.*.side_ids.*' => ['uuid'],
            'items.*.extras' => ['nullable', 'array', 'max:12'],
            'items.*.extras.*.product_id' => ['required', 'uuid'],
            'items.*.extras.*.quantity' => ['nullable', 'integer', 'min:1', 'max:20'],
            'items.*.unit_price' => ['prohibited'],
            'items.*.price' => ['prohibited'],
        ]);

        $order = $this->orders->submit($row, $data);

        return response()->json(['data' => $this->orders->presentGuest($order)], 201);
    }

    public function order(string $token, string $order): JsonResponse
    {
        $row = $this->activeToken($token);

        return response()->json(['data' => $this->orders->show($row, $order)]);
    }

    public function update(Request $request, string $token, string $order): JsonResponse
    {
        $row = $this->activeToken($token);
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1', 'max:40'],
            'items.*.product_id' => ['required', 'uuid'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:20'],
            'items.*.note' => ['nullable', 'string', 'max:200'],
            'items.*.variant_id' => ['nullable', 'uuid'],
            'items.*.sale_unit_id' => ['nullable', 'uuid'],
            'items.*.side_ids' => ['nullable', 'array', 'max:12'],
            'items.*.side_ids.*' => ['uuid'],
            'items.*.extras' => ['nullable', 'array', 'max:12'],
            'items.*.extras.*.product_id' => ['required', 'uuid'],
            'items.*.extras.*.quantity' => ['nullable', 'integer', 'min:1', 'max:20'],
            'items.*.unit_price' => ['prohibited'],
            'items.*.price' => ['prohibited'],
        ]);

        $updated = $this->orders->updateGuest($row, $order, $data);

        return response()->json(['data' => $this->orders->presentGuest($updated)]);
    }

    public function cancel(string $token, string $order): JsonResponse
    {
        $row = $this->activeToken($token);
        $updated = $this->orders->cancel($row, $order);

        return response()->json(['data' => $this->orders->presentGuest($updated)]);
    }

    private function activeToken(string $token): \App\Models\TableQrToken
    {
        $row = $this->orders->findToken($token);
        if ($row === null || ! $row->is_active) {
            abort(404, 'Ce QR code est invalide ou désactivé.');
        }

        return $row;
    }
}
