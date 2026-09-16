<?php

namespace App\Providers;

use App\Models\Barcode;
use App\Models\Branch;
use App\Models\CashRegister;
use App\Models\CashierShift;
use App\Models\Catalog;
use App\Models\Category;
use App\Models\Company;
use App\Models\Currency;
use App\Models\Device;
use App\Models\GoodsReceipt;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\ProductVariant;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseOrder;
use App\Models\PurchaseProforma;
use App\Models\PurchaseRequisition;
use App\Models\Store;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Authorization\AuthorizationService;
use App\Tenancy\TenantContext;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(TenantContext::class);
    }

    public function boot(): void
    {
        $this->configureRateLimiting();
        $this->registerTenantScopedRouteBindings();
        $this->registerAuthorizationGates();
    }

    private function registerAuthorizationGates(): void
    {
        Gate::define('permission', function (User $user, string $permission) {
            return app(AuthorizationService::class)->hasPermission($user, $permission);
        });

        Gate::define('role', function (User $user, string $role) {
            return app(AuthorizationService::class)->hasRole($user, $role);
        });
    }

    private function configureRateLimiting(): void
    {
        RateLimiter::for('auth-login', function (Request $request) {
            $email = (string) $request->input('email');

            return [
                Limit::perMinute(10)->by($request->ip()),
                Limit::perMinute(5)->by($email !== '' ? strtolower($email) : $request->ip()),
            ];
        });

        RateLimiter::for('auth-refresh', fn (Request $request) => Limit::perMinute(30)->by($request->ip()));

        RateLimiter::for('auth-password', function (Request $request) {
            $email = (string) $request->input('email');

            return Limit::perMinute(5)->by($email !== '' ? strtolower($email) : $request->ip());
        });

        RateLimiter::for('auth-phone', fn (Request $request) => Limit::perMinute(3)->by($request->user()?->id ?? $request->ip()));
    }

    private function registerTenantScopedRouteBindings(): void
    {
        $models = [
            'company' => Company::class,
            'currency' => Currency::class,
            'branch' => Branch::class,
            'store' => Store::class,
            'warehouse' => Warehouse::class,
            'device' => Device::class,
            'cashRegister' => CashRegister::class,
            'cashierShift' => CashierShift::class,
            'catalog' => Catalog::class,
            'category' => Category::class,
            'product' => Product::class,
            'productImage' => ProductImage::class,
            'variant' => ProductVariant::class,
            'barcode' => Barcode::class,
            'purchaseOrder' => PurchaseOrder::class,
            'purchaseRequisition' => PurchaseRequisition::class,
            'purchaseProforma' => PurchaseProforma::class,
            'goodsReceipt' => GoodsReceipt::class,
            'purchaseInvoice' => PurchaseInvoice::class,
        ];

        foreach ($models as $key => $modelClass) {
            Route::bind($key, function (string $value) use ($modelClass) {
                $model = $modelClass::query()->find($value);

                if ($model === null) {
                    throw (new ModelNotFoundException)->setModel($modelClass, [$value]);
                }

                return $model;
            });
        }
    }
}
