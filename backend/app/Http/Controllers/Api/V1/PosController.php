<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CashRegister;
use App\Models\Store;
use App\Services\Catalog\PosCatalogSyncService;
use App\Services\Pos\PosOverviewService;
use App\Services\Sales\SaleEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class PosController extends Controller
{
    public function __construct(
        private readonly PosCatalogSyncService $catalogSync,
        private readonly PosOverviewService $overview,
        private readonly SaleEngine $sales,
    ) {}

    public function overview(Request $request, Store $store): JsonResponse
    {
        $date = $request->filled('date')
            ? Carbon::parse($request->string('date'))
            : now();

        return response()->json([
            'data' => $this->overview->forStore($store, $date),
        ]);
    }

    public function catalog(Request $request, Store $store): JsonResponse
    {
        CashRegister::ensureForStore($store);

        $catalogIds = $this->catalogSync->catalogIdsForStore($store);
        $deviceKey = trim((string) $request->header('X-Device-ID', ''));

        return response()->json([
            'data' => [
                'store_id' => $store->id,
                'sale_warehouse_id' => $this->sales->saleWarehouseId($store, $deviceKey === '' ? null : $deviceKey),
                'products' => $this->catalogSync->productsForStore($store, $catalogIds, includeImages: false),
                'categories' => $this->catalogSync->categoriesForStore($store, $catalogIds),
                'stock' => $this->catalogSync->stockLinesForStore($store),
                'registers' => $store->cashRegisters()
                    ->where('is_active', true)
                    ->orderBy('name')
                    ->get(['id', 'name', 'code']),
            ],
        ]);
    }

    public function images(Store $store): JsonResponse
    {
        return response()->json([
            'data' => $this->catalogSync->imageIndexForStore($store),
        ]);
    }

    public function categories(Store $store): JsonResponse
    {
        return response()->json([
            'data' => $this->catalogSync->categoriesForStore($store),
        ]);
    }

    public function products(Store $store): JsonResponse
    {
        return response()->json([
            'data' => $this->catalogSync->productsForStore($store),
        ]);
    }
}
