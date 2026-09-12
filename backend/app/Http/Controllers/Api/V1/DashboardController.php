<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Catalog;
use App\Models\Company;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreProduct;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function stats(): JsonResponse
    {
        return response()->json([
            'data' => [
                'companies' => Company::query()->count(),
                'catalogs' => Catalog::query()->count(),
                'products' => Product::query()->count(),
                'stores' => Store::query()->count(),
                'store_imports' => StoreProduct::query()->count(),
            ],
        ]);
    }
}
