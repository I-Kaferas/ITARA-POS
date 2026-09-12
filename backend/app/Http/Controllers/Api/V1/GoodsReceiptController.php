<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\GoodsReceipt;
use Illuminate\Http\JsonResponse;

class GoodsReceiptController extends Controller
{
    public function show(GoodsReceipt $goodsReceipt): JsonResponse
    {
        return response()->json([
            'data' => $goodsReceipt->load([
                'items.product:id,sku,name',
                'purchaseOrder:id,order_number,status',
                'warehouse:id,name,code',
                'invoice',
                'receivedByUser:id,name',
            ]),
        ]);
    }
}
