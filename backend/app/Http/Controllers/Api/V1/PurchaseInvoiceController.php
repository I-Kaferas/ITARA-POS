<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PurchaseInvoice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PurchaseInvoiceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = PurchaseInvoice::query()
            ->with(['supplier:id,name,code', 'purchaseOrder:id,order_number'])
            ->orderByDesc('invoiced_at');

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json([
            'data' => $query->paginate($request->integer('per_page', 25)),
        ]);
    }

    public function show(PurchaseInvoice $purchaseInvoice): JsonResponse
    {
        return response()->json([
            'data' => $purchaseInvoice->load(['supplier', 'purchaseOrder', 'goodsReceipt', 'payments']),
        ]);
    }
}
