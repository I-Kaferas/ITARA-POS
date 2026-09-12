<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\StockBalance;
use App\Models\Warehouse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StockBalanceController extends Controller
{
    public function index(Request $request, Warehouse $warehouse): JsonResponse
    {
        $query = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->with([
                'product:id,sku,name,category_id,unit_id,unit,base_price,is_active,product_type',
                'product.category:id,name',
                'product.unitModel:id,name,symbol',
                'productVariant:id,sku,name',
                'batch:id,batch_number',
            ])
            ->orderBy('product_id');

        if ($request->boolean('in_stock_only')) {
            $query->where('quantity_on_hand', '>', 0);
        }

        if ($request->filled('product_id')) {
            $query->where('product_id', $request->string('product_id'));
        }

        $balances = $query->paginate($request->integer('per_page', 25));

        $balances->getCollection()->transform(function (StockBalance $balance) {
            return [
                ...$balance->toArray(),
                'quantity_available' => $balance->quantityAvailable(),
            ];
        });

        return response()->json(['data' => $balances]);
    }

    public function show(Warehouse $warehouse, StockBalance $stockBalance): JsonResponse
    {
        abort_unless($stockBalance->warehouse_id === $warehouse->id, 404);

        return response()->json([
            'data' => [
                ...$stockBalance->load(['product', 'productVariant', 'batch', 'warehouse'])->toArray(),
                'quantity_available' => $stockBalance->quantityAvailable(),
            ],
        ]);
    }
}
