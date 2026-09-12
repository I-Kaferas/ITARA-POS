<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Services\Catalog\PosCatalogSyncService;
use App\Services\Pos\PosOverviewService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class PosController extends Controller
{
    public function __construct(
        private readonly PosCatalogSyncService $catalogSync,
        private readonly PosOverviewService $overview,
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

    public function catalog(Store $store): JsonResponse
    {
        return response()->json([
            'data' => [
                'store_id' => $store->id,
                'products' => $this->catalogSync->productsForStore($store),
                'categories' => $this->catalogSync->categoriesForStore($store),
            ],
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
