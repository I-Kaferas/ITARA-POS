<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\CashierShiftStatus;
use App\Enums\InventoryAlertStatus;
use App\Http\Controllers\Controller;
use App\Models\CashierShift;
use App\Models\Catalog;
use App\Models\Company;
use App\Models\InventoryAlert;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreProduct;
use App\Services\Authorization\AuthorizationService;
use App\Services\Performance\ReadCache;
use App\Services\Pos\PosOverviewService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class DashboardController extends Controller
{
    public function __construct(private readonly PosOverviewService $overview) {}

    public function stats(): JsonResponse
    {
        return response()->json(['data' => $this->cachedStats()]);
    }

    public function home(Request $request): JsonResponse
    {
        $storeId = $request->string('store_id')->toString();
        $data = [
            'stats' => $this->cachedStats(),
            'overview' => null,
            'open_shifts' => 0,
            'open_alerts' => 0,
            'alerts' => [],
        ];

        if ($storeId !== '' && $request->boolean('sales') && $this->allows($request, 'sales.view')) {
            $store = Store::query()->findOrFail($storeId);
            $data['overview'] = $this->overview->forStore($store, Carbon::now());
            $data['open_shifts'] = CashierShift::query()
                ->where('status', CashierShiftStatus::Open->value)
                ->whereIn('cash_register_id', function ($query) use ($store) {
                    $query->select('id')->from('cash_registers')->where('store_id', $store->id);
                })
                ->count();
        }

        if ($request->boolean('inventory') && $this->allows($request, 'inventory.view')) {
            $open = InventoryAlert::query()->where('status', '!=', InventoryAlertStatus::Resolved->value);
            $data['open_alerts'] = (clone $open)->count();
            $data['alerts'] = (clone $open)
                ->with('product:id,sku,name')
                ->latest()
                ->limit(6)
                ->get();
        }

        return response()->json(['data' => $data]);
    }

    /** @return array{companies: int, catalogs: int, products: int, stores: int, store_imports: int} */
    private function cachedStats(): array
    {
        return app(ReadCache::class)->remember('catalog', 'dashboard-stats', fn () => [
            'companies' => Company::query()->count(),
            'catalogs' => Catalog::query()->count(),
            'products' => Product::query()->count(),
            'stores' => Store::query()->count(),
            'store_imports' => StoreProduct::query()->count(),
        ]);
    }

    private function allows(Request $request, string $permission): bool
    {
        $user = $request->user();

        return $user !== null && app(AuthorizationService::class)->hasPermission($user, $permission);
    }
}
