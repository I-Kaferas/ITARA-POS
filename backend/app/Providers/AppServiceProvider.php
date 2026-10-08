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
use App\Models\Employee;
use App\Models\GoodsReceipt;
use App\Models\Location;
use App\Models\Party;
use App\Models\Product;
use App\Models\GalleryImage;
use App\Models\ProductImage;
use App\Models\ProductVariant;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseOrder;
use App\Models\PurchaseProforma;
use App\Models\PurchaseRequisition;
use App\Models\Sale;
use App\Models\Store;
use App\Models\StoreProduct;
use App\Models\Tax;
use App\Models\TaxClass;
use App\Models\TaxGroup;
use App\Models\TaxRule;
use App\Models\Transaction;
use App\Models\User;
use App\Models\Warehouse;
use App\Events\PaymentProcessed;
use App\Events\SaleCompleted;
use App\Listeners\NotifyPaymentProcessed;
use App\Listeners\NotifySaleCompleted;
use App\Services\Authorization\AuthorizationService;
use App\Services\Performance\ReadCache;
use App\Models\Tenant;
use App\Tenancy\TenantContext;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\Request;
use Illuminate\Queue\Events\JobFailed;
use Illuminate\Queue\Events\JobProcessed;
use Illuminate\Queue\Events\JobProcessing;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Queue;
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
        $this->registerPageSize();
        $this->registerReadCacheInvalidation();
        $this->registerTenantScopedRouteBindings();
        $this->registerAuthorizationGates();
        $this->registerTenantAwareQueue();
        $this->registerNotificationListeners();
    }

    private function registerPageSize(): void
    {
        Request::macro('pageSize', function (int $default = 25): int {
            $max = max(1, (int) config('performance.max_page_size', 100));
            $size = (int) $this->input('per_page', $default);

            if ($size < 1) {
                $size = $default;
            }

            return min($max, $size);
        });
    }

    private function registerReadCacheInvalidation(): void
    {
        $bump = function (string $bucket): void {
            app(ReadCache::class)->bump($bucket);
        };

        foreach ([Sale::class] as $model) {
            $model::saved(fn () => $bump('sales'));
            $model::deleted(fn () => $bump('sales'));
        }

        foreach ([Product::class, Store::class, Catalog::class, Company::class, StoreProduct::class] as $model) {
            $model::saved(fn () => $bump('catalog'));
            $model::deleted(fn () => $bump('catalog'));
        }
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

    private function registerTenantAwareQueue(): void
    {
        Queue::createPayloadUsing(function (): array {
            $tenantId = app(TenantContext::class)->id();

            return $tenantId ? ['tenant_id' => $tenantId] : [];
        });

        $restore = function (JobProcessing $event): void {
            $tenantId = $event->job->payload()['tenant_id'] ?? null;
            $context = app(TenantContext::class);
            $context->clear();
            if (! is_string($tenantId) || $tenantId === '') {
                return;
            }
            $tenant = Tenant::query()->find($tenantId);
            if ($tenant) {
                $context->bind($tenant);
            }
        };

        Queue::before($restore);
        $clear = function (): void {
            app(TenantContext::class)->clear();
        };
        Queue::after(function (JobProcessed $event) use ($clear): void {
            $clear();
        });
        Queue::failing(function (JobFailed $event) use ($clear): void {
            $clear();
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

    private function registerNotificationListeners(): void
    {
        Event::listen(SaleCompleted::class, NotifySaleCompleted::class);
        Event::listen(PaymentProcessed::class, NotifyPaymentProcessed::class);
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
            'galleryImage' => GalleryImage::class,
            'variant' => ProductVariant::class,
            'barcode' => Barcode::class,
            'purchaseOrder' => PurchaseOrder::class,
            'purchaseRequisition' => PurchaseRequisition::class,
            'purchaseProforma' => PurchaseProforma::class,
            'goodsReceipt' => GoodsReceipt::class,
            'purchaseInvoice' => PurchaseInvoice::class,
            'transaction' => Transaction::class,
            'tax' => Tax::class,
            'taxGroup' => TaxGroup::class,
            'taxClass' => TaxClass::class,
            'taxRule' => TaxRule::class,
            'party' => Party::class,
            'employee' => Employee::class,
            'location' => Location::class,
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
