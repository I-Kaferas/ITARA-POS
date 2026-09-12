<?php

use App\Http\Controllers\Api\V1\CartController;
use App\Http\Controllers\Api\V1\CashierShiftController;
use App\Http\Controllers\Api\V1\CashRegisterController;
use App\Http\Controllers\Api\V1\AccountingEntryController;
use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BarcodeController;
use App\Http\Controllers\Api\V1\BeverageController;
use App\Http\Controllers\Api\V1\BatchController;
use App\Http\Controllers\Api\V1\BranchController;
use App\Http\Controllers\Api\V1\BrandController;
use App\Http\Controllers\Api\V1\CatalogController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\CompanyController;
use App\Http\Controllers\Api\V1\CompanyPaymentMethodController;
use App\Http\Controllers\Api\V1\CurrencyController;
use App\Http\Controllers\Api\V1\CustomerAddressController;
use App\Http\Controllers\Api\V1\CustomerController;
use App\Http\Controllers\Api\V1\CustomerPaymentController;
use App\Http\Controllers\Api\V1\CustomerTransactionController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\EmailVerificationController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\ImportExportController;
use App\Http\Controllers\Api\V1\InventoryAlertController;
use App\Http\Controllers\Api\V1\InventoryCountController;
use App\Http\Controllers\Api\V1\InventoryVerificationController;
use App\Http\Controllers\Api\V1\InventoryMovementController;
use App\Http\Controllers\Api\V1\PasswordResetController;
use App\Http\Controllers\Api\V1\PermissionController;
use App\Http\Controllers\Api\V1\PhoneVerificationController;
use App\Http\Controllers\Api\V1\PayableController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\PosController;
use App\Http\Controllers\Api\V1\PosReservationController;
use App\Http\Controllers\Api\V1\RefundController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\SaleController;
use App\Http\Controllers\Api\V1\SerialNumberController;
use App\Http\Controllers\Api\V1\SaleReturnController;
use App\Http\Controllers\Api\V1\SaleInvoiceController;
use App\Http\Controllers\Api\V1\SaleReceiptController;
use App\Http\Controllers\Api\V1\PriceController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\ProductImageController;
use App\Http\Controllers\Api\V1\ProductOptionController;
use App\Http\Controllers\Api\V1\ProductVariantController;
use App\Http\Controllers\Api\V1\PromotionController;
use App\Http\Controllers\Api\V1\PurchaseInvoiceController;
use App\Http\Controllers\Api\V1\ExpenseController;
use App\Http\Controllers\Api\V1\PurchaseCycleController;
use App\Http\Controllers\Api\V1\PurchaseOrderController;
use App\Http\Controllers\Api\V1\PurchasePaymentController;
use App\Http\Controllers\Api\V1\GoodsReceiptController;
use App\Http\Controllers\Api\V1\RoleController;
use App\Http\Controllers\Api\V1\SessionController;
use App\Http\Controllers\Api\V1\StoreController;
use App\Http\Controllers\Api\V1\StockAdjustmentController;
use App\Http\Controllers\Api\V1\StockBalanceController;
use App\Http\Controllers\Api\V1\StockTransferController;
use App\Http\Controllers\Api\V1\StoreProductController;
use App\Http\Controllers\Api\V1\SupplierContactController;
use App\Http\Controllers\Api\V1\SupplierController;
use App\Http\Controllers\Api\V1\SupplierPaymentController;
use App\Http\Controllers\Api\V1\SupplierTransactionController;
use App\Http\Controllers\Api\V1\TaxController;
use App\Http\Controllers\Api\V1\TenantBrandingController;
use App\Http\Controllers\Api\V1\SyncController;
use App\Http\Controllers\Api\V1\TwoFactorController;
use App\Http\Controllers\Api\V1\UnitController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\UserRoleController;
use App\Http\Controllers\Api\V1\WarehouseController;
use App\Http\Middleware\AuthenticateApiToken;
use App\Http\Middleware\ResolveStore;
use App\Http\Middleware\ResolveTenant;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('/health', [HealthController::class, 'health']);
    Route::get('/ready', [HealthController::class, 'ready']);

    Route::get('/public/tenants/{slug}/branding', [TenantBrandingController::class, 'publicShow'])
        ->middleware('throttle:60,1');

    Route::middleware('throttle:auth-login')->group(function () {
        Route::post('/auth/login', [AuthController::class, 'login']);
        Route::post('/auth/pin-login', [AuthController::class, 'pinLogin']);
        Route::post('/auth/two-factor/challenge', [TwoFactorController::class, 'challenge']);
    });

    Route::middleware('throttle:auth-refresh')->group(function () {
        Route::post('/auth/refresh', [AuthController::class, 'refresh']);
    });

    Route::middleware('throttle:auth-password')->group(function () {
        Route::post('/auth/forgot-password', [PasswordResetController::class, 'forgotPassword']);
        Route::post('/auth/reset-password', [PasswordResetController::class, 'resetPassword']);
    });

    Route::get('/auth/email/verify/{id}/{hash}', [EmailVerificationController::class, 'verify'])
        ->middleware(['signed', 'throttle:6,1'])
        ->name('verification.verify');

    Route::middleware([AuthenticateApiToken::class, ResolveTenant::class, ResolveStore::class])->group(function () {
        // Auth (no extra permission — authenticated user)
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::post('/auth/logout-all', [AuthController::class, 'logoutAll']);
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::patch('/auth/profile', [AuthController::class, 'updateProfile']);

        Route::post('/auth/email/resend', [EmailVerificationController::class, 'send'])
            ->middleware('throttle:6,1');
        Route::get('/auth/email/status', [EmailVerificationController::class, 'status']);

        Route::post('/auth/phone/send', [PhoneVerificationController::class, 'send'])
            ->middleware('throttle:auth-phone');
        Route::post('/auth/phone/verify', [PhoneVerificationController::class, 'verify'])
            ->middleware('throttle:auth-phone');

        Route::get('/auth/two-factor/status', [TwoFactorController::class, 'status']);
        Route::post('/auth/two-factor/setup', [TwoFactorController::class, 'setup']);
        Route::post('/auth/two-factor/confirm', [TwoFactorController::class, 'confirm']);
        Route::post('/auth/two-factor/disable', [TwoFactorController::class, 'disable']);

        Route::get('/auth/sessions', [SessionController::class, 'index']);
        Route::delete('/auth/sessions/others', [SessionController::class, 'destroyOthers']);
        Route::delete('/auth/sessions/{session}', [SessionController::class, 'destroy']);

        // RBAC management
        Route::get('/permissions', [PermissionController::class, 'index'])
            ->middleware('permission:roles.view,roles.manage');

        Route::get('/roles', [RoleController::class, 'index'])
            ->middleware('permission:roles.view,roles.manage');
        Route::get('/roles/{role}', [RoleController::class, 'show'])
            ->middleware('permission:roles.view,roles.manage');
        Route::post('/roles', [RoleController::class, 'store'])
            ->middleware('permission:roles.manage');
        Route::patch('/roles/{role}', [RoleController::class, 'update'])
            ->middleware('permission:roles.manage');
        Route::delete('/roles/{role}', [RoleController::class, 'destroy'])
            ->middleware('permission:roles.manage');

        Route::get('/users/{user}/roles', [UserRoleController::class, 'index'])
            ->middleware('permission:users.view,users.manage');
        Route::post('/users/{user}/roles', [UserRoleController::class, 'store'])
            ->middleware('permission:users.manage');
        Route::patch('/users/{user}/store', [UserController::class, 'assignStore'])
            ->middleware('permission:users.manage');
        Route::delete('/users/{user}/roles/{role}', [UserRoleController::class, 'destroy'])
            ->middleware('permission:users.manage');

        Route::get('/users', [UserController::class, 'index'])
            ->middleware('permission:users.view,users.manage');
        Route::post('/users', [UserController::class, 'store'])
            ->middleware('permission:users.manage');
        Route::get('/users/{user}', [UserController::class, 'show'])
            ->middleware('permission:users.view,users.manage');
        Route::patch('/users/{user}', [UserController::class, 'update'])
            ->middleware('permission:users.manage');
        Route::post('/users/{user}/reset-password', [UserController::class, 'resetPassword'])
            ->middleware('permission:users.manage');
        Route::post('/users/{user}/activate', [UserController::class, 'activate'])
            ->middleware('permission:users.manage');
        Route::post('/users/{user}/deactivate', [UserController::class, 'deactivate'])
            ->middleware('permission:users.manage');
        Route::get('/users/{user}/sessions', [UserController::class, 'sessions'])
            ->middleware('permission:users.view,users.manage');
        Route::delete('/users/{user}/sessions', [UserController::class, 'revokeSessions'])
            ->middleware('permission:users.manage');
        Route::delete('/users/{user}', [UserController::class, 'destroy'])
            ->middleware('permission:users.manage');

        // Dashboard
        Route::get('/dashboard/stats', [DashboardController::class, 'stats'])
            ->middleware('permission:dashboard.view');

        // Reports
        Route::get('/reports/sales', [ReportController::class, 'sales'])
            ->middleware('permission:reports.view');
        Route::get('/reports/inventory', [ReportController::class, 'inventory'])
            ->middleware('permission:reports.view');
        Route::get('/reports/financial', [ReportController::class, 'financial'])
            ->middleware('permission:reports.view');
        Route::get('/reports/export/sales', [ReportController::class, 'exportSales'])
            ->middleware('permission:reports.export');
        Route::get('/reports/export/inventory', [ReportController::class, 'exportInventory'])
            ->middleware('permission:reports.export');

        // Audit
        Route::get('/audit-logs', [AuditLogController::class, 'index'])
            ->middleware('permission:audit.view');
        Route::get('/audit-logs/{auditLog}', [AuditLogController::class, 'show'])
            ->middleware('permission:audit.view');

        // Accounting
        Route::get('/accounting/types', [AccountingEntryController::class, 'types'])
            ->middleware('permission:accounting.view,accounting.manage');
        Route::get('/accounting/summary', [AccountingEntryController::class, 'summary'])
            ->middleware('permission:accounting.view,accounting.manage');
        Route::get('/accounting/entries', [AccountingEntryController::class, 'index'])
            ->middleware('permission:accounting.view,accounting.manage');
        Route::post('/accounting/entries', [AccountingEntryController::class, 'storeManual'])
            ->middleware('permission:accounting.manage');
        Route::get('/accounting/entries/{accountingEntry}', [AccountingEntryController::class, 'show'])
            ->middleware('permission:accounting.view,accounting.manage');
        Route::get('/accounting/accounts', [AccountingEntryController::class, 'accounts'])
            ->middleware('permission:accounting.view,accounting.manage');
        Route::post('/accounting/letter', [AccountingEntryController::class, 'letter'])
            ->middleware('permission:accounting.manage');
        Route::post('/accounting/periods/close', [AccountingEntryController::class, 'closePeriod'])
            ->middleware('permission:accounting.manage');

        // Import / Export
        Route::get('/import-export/products/template', [ImportExportController::class, 'productTemplate'])
            ->middleware('permission:catalog.products.manage');
        Route::get('/import-export/products/export', [ImportExportController::class, 'exportProducts'])
            ->middleware('permission:catalog.products.view,reports.export');
        Route::post('/import-export/products/import', [ImportExportController::class, 'importProducts'])
            ->middleware('permission:catalog.products.manage');

        // Tenant branding (marketing / white-label)
        Route::get('tenant/branding', [TenantBrandingController::class, 'show'])
            ->middleware('permission:settings.manage,organization.companies.view');
        Route::put('tenant/branding', [TenantBrandingController::class, 'update'])
            ->middleware('permission:settings.manage,organization.companies.manage');

        // Companies
        Route::get('companies', [CompanyController::class, 'index'])
            ->middleware('permission:organization.companies.view');
        Route::post('companies', [CompanyController::class, 'store'])
            ->middleware('permission:organization.companies.manage');
        Route::get('companies/{company}', [CompanyController::class, 'show'])
            ->middleware('permission:organization.companies.view');
        Route::patch('companies/{company}', [CompanyController::class, 'update'])
            ->middleware('permission:organization.companies.manage');
        Route::post('companies/{company}/logo', [CompanyController::class, 'uploadLogo'])
            ->middleware('permission:organization.companies.manage');
        Route::delete('companies/{company}/logo', [CompanyController::class, 'deleteLogo'])
            ->middleware('permission:organization.companies.manage');
        Route::delete('companies/{company}', [CompanyController::class, 'destroy'])
            ->middleware('permission:organization.companies.manage');

        // Company payment methods (POS tenders)
        Route::get('payment-method-catalog', [CompanyPaymentMethodController::class, 'catalog'])
            ->middleware('permission:organization.payment_methods.view,organization.companies.view,sales.view');
        Route::get('companies/{company}/payment-methods', [CompanyPaymentMethodController::class, 'index'])
            ->middleware('permission:organization.payment_methods.view,organization.companies.view,sales.view');
        Route::post('companies/{company}/payment-methods', [CompanyPaymentMethodController::class, 'store'])
            ->middleware('permission:organization.payment_methods.manage,organization.companies.manage');
        Route::patch('companies/{company}/payment-methods/{paymentMethod}', [CompanyPaymentMethodController::class, 'update'])
            ->middleware('permission:organization.payment_methods.manage,organization.companies.manage');
        Route::delete('companies/{company}/payment-methods/{paymentMethod}', [CompanyPaymentMethodController::class, 'destroy'])
            ->middleware('permission:organization.payment_methods.manage,organization.companies.manage');
        Route::post('companies/{company}/payment-methods/reorder', [CompanyPaymentMethodController::class, 'reorder'])
            ->middleware('permission:organization.payment_methods.manage,organization.companies.manage');

        // Currencies
        Route::get('currencies', [CurrencyController::class, 'index'])
            ->middleware('permission:organization.currencies.view,organization.companies.view');
        Route::post('currencies', [CurrencyController::class, 'store'])
            ->middleware('permission:organization.currencies.manage');
        Route::get('currencies/{currency}', [CurrencyController::class, 'show'])
            ->middleware('permission:organization.currencies.view,organization.companies.view');
        Route::patch('currencies/{currency}', [CurrencyController::class, 'update'])
            ->middleware('permission:organization.currencies.manage');
        Route::delete('currencies/{currency}', [CurrencyController::class, 'destroy'])
            ->middleware('permission:organization.currencies.manage');

        // Branches
        Route::get('companies/{company}/branches', [BranchController::class, 'index'])
            ->middleware('permission:organization.branches.view');
        Route::post('companies/{company}/branches', [BranchController::class, 'store'])
            ->middleware('permission:organization.branches.manage');
        Route::patch('branches/{branch}', [BranchController::class, 'update'])
            ->middleware('permission:organization.branches.manage');
        Route::delete('branches/{branch}', [BranchController::class, 'destroy'])
            ->middleware('permission:organization.branches.manage');

        // Stores
        Route::get('stores', [StoreController::class, 'indexAll'])
            ->middleware('permission:organization.stores.view');
        Route::get('branches/{branch}/stores', [StoreController::class, 'index'])
            ->middleware('permission:organization.stores.view');
        Route::post('branches/{branch}/stores', [StoreController::class, 'store'])
            ->middleware('permission:organization.stores.manage');
        Route::get('stores/{store}', [StoreController::class, 'show'])
            ->middleware('permission:organization.stores.view');
        Route::patch('stores/{store}', [StoreController::class, 'update'])
            ->middleware('permission:organization.stores.manage');
        Route::delete('stores/{store}', [StoreController::class, 'destroy'])
            ->middleware('permission:organization.stores.manage');

        // Warehouses
        Route::get('branches/{branch}/warehouses', [WarehouseController::class, 'index'])
            ->middleware('permission:organization.warehouses.view');
        Route::post('branches/{branch}/warehouses', [WarehouseController::class, 'store'])
            ->middleware('permission:organization.warehouses.manage');
        Route::patch('warehouses/{warehouse}', [WarehouseController::class, 'update'])
            ->middleware('permission:organization.warehouses.manage');
        Route::delete('warehouses/{warehouse}', [WarehouseController::class, 'destroy'])
            ->middleware('permission:organization.warehouses.manage');

        // Devices
        Route::get('stores/{store}/devices', [DeviceController::class, 'index'])
            ->middleware('permission:organization.devices.view');
        Route::post('stores/{store}/devices', [DeviceController::class, 'store'])
            ->middleware('permission:organization.devices.manage');
        Route::post('stores/{store}/devices/register', [DeviceController::class, 'register'])
            ->middleware('permission:sales.create');
        Route::post('devices/pair', [DeviceController::class, 'pair'])
            ->middleware('permission:sales.create,organization.devices.manage');
        Route::post('devices/{device}/sync-token', [DeviceController::class, 'regenerateToken'])
            ->middleware('permission:organization.devices.manage');
        Route::patch('devices/{device}', [DeviceController::class, 'update'])
            ->middleware('permission:organization.devices.manage');
        Route::delete('devices/{device}', [DeviceController::class, 'destroy'])
            ->middleware('permission:organization.devices.manage');

        // Catalogs
        Route::get('companies/{company}/catalogs', [CatalogController::class, 'index'])
            ->middleware('permission:catalog.catalogs.view');
        Route::post('companies/{company}/catalogs', [CatalogController::class, 'store'])
            ->middleware('permission:catalog.catalogs.manage');
        Route::get('catalogs/{catalog}', [CatalogController::class, 'show'])
            ->middleware('permission:catalog.catalogs.view');
        Route::patch('catalogs/{catalog}', [CatalogController::class, 'update'])
            ->middleware('permission:catalog.catalogs.manage');
        Route::delete('catalogs/{catalog}', [CatalogController::class, 'destroy'])
            ->middleware('permission:catalog.catalogs.manage');

        // Categories
        Route::get('catalogs/{catalog}/categories', [CategoryController::class, 'index'])
            ->middleware('permission:catalog.categories.view');
        Route::post('catalogs/{catalog}/categories', [CategoryController::class, 'store'])
            ->middleware('permission:catalog.categories.manage');
        Route::get('categories/{category}', [CategoryController::class, 'show'])
            ->middleware('permission:catalog.categories.view');
        Route::patch('categories/{category}', [CategoryController::class, 'update'])
            ->middleware('permission:catalog.categories.manage');
        Route::delete('categories/{category}', [CategoryController::class, 'destroy'])
            ->middleware('permission:catalog.categories.manage');

        // Products
        Route::get('catalogs/{catalog}/products', [ProductController::class, 'index'])
            ->middleware('permission:catalog.products.view');
        Route::post('catalogs/{catalog}/products', [ProductController::class, 'store'])
            ->middleware('permission:catalog.products.manage');
        Route::get('products/{product}', [ProductController::class, 'show'])
            ->middleware('permission:catalog.products.view');
        Route::patch('products/{product}', [ProductController::class, 'update'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('products/{product}', [ProductController::class, 'destroy'])
            ->middleware('permission:catalog.products.manage');

        // Product images
        Route::get('products/{product}/images', [ProductImageController::class, 'index'])
            ->middleware('permission:catalog.products.view');
        Route::post('products/{product}/images', [ProductImageController::class, 'store'])
            ->middleware('permission:catalog.products.manage');
        Route::patch('products/{product}/images/reorder', [ProductImageController::class, 'reorder'])
            ->middleware('permission:catalog.products.manage');
        Route::patch('product-images/{productImage}/primary', [ProductImageController::class, 'setPrimary'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('product-images/{productImage}', [ProductImageController::class, 'destroy'])
            ->middleware('permission:catalog.products.manage');

        // Store products
        Route::get('stores/{store}/products', [StoreProductController::class, 'index'])
            ->middleware('permission:catalog.products.view');
        Route::post('stores/{store}/products/import', [StoreProductController::class, 'import'])
            ->middleware('permission:catalog.products.manage');
        Route::patch('stores/{store}/products/{product}', [StoreProductController::class, 'update'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('stores/{store}/products/{product}', [StoreProductController::class, 'destroy'])
            ->middleware('permission:catalog.products.manage');

        // Brands
        Route::get('brands', [BrandController::class, 'index'])
            ->middleware('permission:catalog.products.view');
        Route::post('brands', [BrandController::class, 'store'])
            ->middleware('permission:catalog.products.manage');
        Route::get('brands/{brand}', [BrandController::class, 'show'])
            ->middleware('permission:catalog.products.view');
        Route::patch('brands/{brand}', [BrandController::class, 'update'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('brands/{brand}', [BrandController::class, 'destroy'])
            ->middleware('permission:catalog.products.manage');

        // Units
        Route::get('units', [UnitController::class, 'index'])
            ->middleware('permission:catalog.products.view');
        Route::post('units', [UnitController::class, 'store'])
            ->middleware('permission:catalog.products.manage');
        Route::get('units/{unit}', [UnitController::class, 'show'])
            ->middleware('permission:catalog.products.view');
        Route::patch('units/{unit}', [UnitController::class, 'update'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('units/{unit}', [UnitController::class, 'destroy'])
            ->middleware('permission:catalog.products.manage');

        // Taxes
        Route::get('taxes', [TaxController::class, 'index'])
            ->middleware('permission:catalog.products.view');
        Route::get('taxes/report', [TaxController::class, 'report'])
            ->middleware('permission:catalog.products.view');
        Route::get('taxes/register', [TaxController::class, 'register'])
            ->middleware('permission:catalog.products.view');
        Route::post('taxes/calculate', [TaxController::class, 'calculate'])
            ->middleware('permission:catalog.products.view');
        Route::post('taxes', [TaxController::class, 'store'])
            ->middleware('permission:catalog.products.manage');
        Route::get('tax-groups', [TaxController::class, 'groups'])
            ->middleware('permission:catalog.products.view');
        Route::post('tax-groups', [TaxController::class, 'storeGroup'])
            ->middleware('permission:catalog.products.manage');
        Route::patch('tax-groups/{taxGroup}', [TaxController::class, 'updateGroup'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('tax-groups/{taxGroup}', [TaxController::class, 'destroyGroup'])
            ->middleware('permission:catalog.products.manage');
        Route::get('tax-classes', [TaxController::class, 'classes'])
            ->middleware('permission:catalog.products.view');
        Route::post('tax-classes', [TaxController::class, 'storeClass'])
            ->middleware('permission:catalog.products.manage');
        Route::patch('tax-classes/{taxClass}', [TaxController::class, 'updateClass'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('tax-classes/{taxClass}', [TaxController::class, 'destroyClass'])
            ->middleware('permission:catalog.products.manage');
        Route::get('tax-rules', [TaxController::class, 'rules'])
            ->middleware('permission:catalog.products.view');
        Route::post('tax-rules', [TaxController::class, 'storeRule'])
            ->middleware('permission:catalog.products.manage');
        Route::patch('tax-rules/{taxRule}', [TaxController::class, 'updateRule'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('tax-rules/{taxRule}', [TaxController::class, 'destroyRule'])
            ->middleware('permission:catalog.products.manage');
        Route::get('taxes/{tax}', [TaxController::class, 'show'])
            ->middleware('permission:catalog.products.view');
        Route::patch('taxes/{tax}', [TaxController::class, 'update'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('taxes/{tax}', [TaxController::class, 'destroy'])
            ->middleware('permission:catalog.products.manage');

        // Product variants
        Route::get('products/{product}/variants', [ProductVariantController::class, 'index'])
            ->middleware('permission:catalog.products.view');
        Route::post('products/{product}/variants', [ProductVariantController::class, 'store'])
            ->middleware('permission:catalog.products.manage');
        Route::get('variants/{variant}', [ProductVariantController::class, 'show'])
            ->middleware('permission:catalog.products.view');
        Route::patch('variants/{variant}', [ProductVariantController::class, 'update'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('variants/{variant}', [ProductVariantController::class, 'destroy'])
            ->middleware('permission:catalog.products.manage');

        Route::get('products/{product}/options', [ProductOptionController::class, 'show'])
            ->middleware('permission:catalog.products.view');
        Route::post('products/{product}/transform-options', [ProductOptionController::class, 'transform'])
            ->middleware('permission:catalog.products.manage');

        Route::get('beverages', [BeverageController::class, 'index'])
            ->middleware('permission:catalog.products.view,sales.view');
        Route::post('products/{product}/sale-units', [BeverageController::class, 'save'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('products/{product}/sale-units/{saleUnit}', [BeverageController::class, 'destroyUnit'])
            ->middleware('permission:catalog.products.manage');

        // Product prices
        Route::get('prices/types', [PriceController::class, 'types'])
            ->middleware('permission:catalog.products.view');
        Route::get('stores/{store}/products/{product}/resolve-price', [PriceController::class, 'resolveForStoreProduct'])
            ->middleware('permission:sales.view,catalog.products.view');
        Route::get('products/{product}/prices', [PriceController::class, 'indexForProduct'])
            ->middleware('permission:catalog.products.view');
        Route::post('products/{product}/prices', [PriceController::class, 'storeForProduct'])
            ->middleware('permission:catalog.products.manage');
        Route::get('variants/{variant}/prices', [PriceController::class, 'indexForVariant'])
            ->middleware('permission:catalog.products.view');
        Route::post('variants/{variant}/prices', [PriceController::class, 'storeForVariant'])
            ->middleware('permission:catalog.products.manage');
        Route::patch('prices/{price}', [PriceController::class, 'update'])
            ->middleware('permission:catalog.products.manage');
        Route::delete('prices/{price}', [PriceController::class, 'destroy'])
            ->middleware('permission:catalog.products.manage');

        // Promotions (Phase 19 — MOD-PROMO)
        Route::get('promotions/types', [PromotionController::class, 'types'])
            ->middleware('permission:promotions.view,promotions.manage');
        Route::get('promotions', [PromotionController::class, 'index'])
            ->middleware('permission:promotions.view,promotions.manage');
        Route::post('promotions', [PromotionController::class, 'store'])
            ->middleware('permission:promotions.manage');
        Route::get('promotions/{promotion}', [PromotionController::class, 'show'])
            ->middleware('permission:promotions.view,promotions.manage');
        Route::patch('promotions/{promotion}', [PromotionController::class, 'update'])
            ->middleware('permission:promotions.manage');
        Route::delete('promotions/{promotion}', [PromotionController::class, 'destroy'])
            ->middleware('permission:promotions.manage');
        Route::get('stores/{store}/promotions/active', [PromotionController::class, 'activeForStore'])
            ->middleware('permission:promotions.view,sales.view');

        // Cash registers (Phase 20 — MOD-REGISTER)
        Route::get('registers/movement-types', [CashRegisterController::class, 'movementTypes'])
            ->middleware('permission:registers.view,registers.manage');
        Route::get('stores/{store}/cash-registers', [CashRegisterController::class, 'index'])
            ->middleware('permission:registers.view,registers.manage');
        Route::post('stores/{store}/cash-registers', [CashRegisterController::class, 'store'])
            ->middleware('permission:registers.manage');
        Route::get('cash-registers/{cashRegister}', [CashRegisterController::class, 'show'])
            ->middleware('permission:registers.view,registers.manage');
        Route::patch('cash-registers/{cashRegister}', [CashRegisterController::class, 'update'])
            ->middleware('permission:registers.manage');
        Route::delete('cash-registers/{cashRegister}', [CashRegisterController::class, 'destroy'])
            ->middleware('permission:registers.manage');
        Route::get('cash-registers/{cashRegister}/sessions/current', [CashRegisterController::class, 'currentSession'])
            ->middleware('permission:registers.view,registers.session.open');
        Route::post('cash-registers/{cashRegister}/sessions/open', [CashRegisterController::class, 'openSession'])
            ->middleware('permission:registers.session.open');
        Route::post('cash-registers/{cashRegister}/sessions/close', [CashRegisterController::class, 'closeSession'])
            ->middleware('permission:registers.session.close');
        Route::get('cash-registers/{cashRegister}/sessions', [CashRegisterController::class, 'sessions'])
            ->middleware('permission:registers.view');
        Route::get('cash-registers/{cashRegister}/sessions/{session}', [CashRegisterController::class, 'showSession'])
            ->middleware('permission:registers.view');
        Route::get('cash-registers/{cashRegister}/movements', [CashRegisterController::class, 'movements'])
            ->middleware('permission:registers.view');
        Route::post('cash-registers/{cashRegister}/movements', [CashRegisterController::class, 'recordMovement'])
            ->middleware('permission:registers.movement.record');

        // Cashier shifts (Phase 21 — MOD-SHIFT)
        Route::get('me/cashier-shifts/current', [CashierShiftController::class, 'currentForUser'])
            ->middleware('permission:shifts.view,shifts.manage');
        Route::get('stores/{store}/cashier-shifts', [CashierShiftController::class, 'indexForStore'])
            ->middleware('permission:shifts.view,shifts.manage');
        Route::get('stores/{store}/cashier-shifts/{cashierShift}', [CashierShiftController::class, 'showForStore'])
            ->middleware('permission:shifts.view,shifts.manage');
        Route::get('cash-registers/{cashRegister}/cashier-shifts/current', [CashierShiftController::class, 'currentOnRegister'])
            ->middleware('permission:shifts.view,shifts.open');
        Route::post('cash-registers/{cashRegister}/cashier-shifts/open', [CashierShiftController::class, 'open'])
            ->middleware('permission:shifts.open');
        Route::post('cash-registers/{cashRegister}/cashier-shifts/close', [CashierShiftController::class, 'close'])
            ->middleware('permission:shifts.close');
        Route::get('cash-registers/{cashRegister}/cashier-shifts', [CashierShiftController::class, 'index'])
            ->middleware('permission:shifts.view');
        Route::get('cash-registers/{cashRegister}/cashier-shifts/{cashierShift}', [CashierShiftController::class, 'show'])
            ->middleware('permission:shifts.view');
        Route::post('cash-registers/{cashRegister}/cashier-shifts/{cashierShift}/movements', [CashierShiftController::class, 'recordMovement'])
            ->middleware('permission:shifts.movement.record');

        // Barcodes (Phase 10 — MOD-BARCODE)
        Route::get('barcodes/types', [BarcodeController::class, 'types'])
            ->middleware('permission:catalog.barcodes.view,catalog.products.view');
        Route::get('barcodes/lookup', [BarcodeController::class, 'lookup'])
            ->middleware('permission:catalog.barcodes.view,catalog.products.view');
        Route::get('barcodes/search', [BarcodeController::class, 'search'])
            ->middleware('permission:catalog.barcodes.view,catalog.products.view');
        Route::post('barcodes/generate', [BarcodeController::class, 'generate'])
            ->middleware('permission:catalog.barcodes.manage,catalog.products.manage');
        Route::get('stores/{store}/barcodes', [BarcodeController::class, 'indexForStore'])
            ->middleware('permission:catalog.barcodes.view,catalog.products.view');
        Route::get('products/{product}/barcodes', [BarcodeController::class, 'indexForProduct'])
            ->middleware('permission:catalog.barcodes.view,catalog.products.view');
        Route::post('products/{product}/barcodes', [BarcodeController::class, 'storeForProduct'])
            ->middleware('permission:catalog.barcodes.manage,catalog.products.manage');
        Route::get('variants/{variant}/barcodes', [BarcodeController::class, 'indexForVariant'])
            ->middleware('permission:catalog.barcodes.view,catalog.products.view');
        Route::post('variants/{variant}/barcodes', [BarcodeController::class, 'storeForVariant'])
            ->middleware('permission:catalog.barcodes.manage,catalog.products.manage');
        Route::get('barcodes/{barcode}/print', [BarcodeController::class, 'printLabel'])
            ->middleware('permission:catalog.barcodes.view,catalog.products.view');
        Route::patch('barcodes/{barcode}', [BarcodeController::class, 'update'])
            ->middleware('permission:catalog.barcodes.manage,catalog.products.manage');
        Route::delete('barcodes/{barcode}', [BarcodeController::class, 'destroy'])
            ->middleware('permission:catalog.barcodes.manage,catalog.products.manage');

        // Inventory (Phase 11 — MOD-INVENTORY)
        Route::get('inventory-verifications/dashboard', [InventoryVerificationController::class, 'dashboard'])
            ->middleware('permission:inventory.view');
        Route::get('inventory-verifications/suggestions', [InventoryVerificationController::class, 'suggestions'])
            ->middleware('permission:inventory.view');
        Route::get('inventory-verifications/plans', [InventoryVerificationController::class, 'plans'])
            ->middleware('permission:inventory.view');
        Route::post('inventory-verifications/plans', [InventoryVerificationController::class, 'storePlan'])
            ->middleware('permission:inventory.cycle.configure,inventory.adjust');
        Route::post('inventory-verifications/run', [InventoryVerificationController::class, 'run'])
            ->middleware('permission:inventory.count.enter,inventory.adjust');
        Route::get('inventory-verifications/runs', [InventoryVerificationController::class, 'runs'])
            ->middleware('permission:inventory.view');
        Route::get('inventory-verifications/runs/{inventoryVerificationRun}', [InventoryVerificationController::class, 'show'])
            ->middleware('permission:inventory.view');
        Route::post('inventory-verifications/runs/{inventoryVerificationRun}/validate', [InventoryVerificationController::class, 'validateRun'])
            ->middleware('permission:inventory.count.review,inventory.adjust');
        Route::post('inventory-verifications/findings/{inventoryVerificationFinding}/resolve', [InventoryVerificationController::class, 'resolve'])
            ->middleware('permission:inventory.count.review,inventory.adjust');

        Route::get('inventory/movement-types', [InventoryMovementController::class, 'types'])
            ->middleware('permission:inventory.view');
        Route::get('warehouses/{warehouse}/movements', [InventoryMovementController::class, 'index'])
            ->middleware('permission:inventory.view');
        Route::post('warehouses/{warehouse}/movements', [InventoryMovementController::class, 'store'])
            ->middleware('permission:inventory.manage');
        Route::get('warehouses/{warehouse}/stock', [StockBalanceController::class, 'index'])
            ->middleware('permission:inventory.view');
        Route::get('warehouses/{warehouse}/stock/{stockBalance}', [StockBalanceController::class, 'show'])
            ->middleware('permission:inventory.view');

        Route::get('stock-transfers', [StockTransferController::class, 'index'])
            ->middleware('permission:inventory.view');
        Route::post('stock-transfers', [StockTransferController::class, 'store'])
            ->middleware('permission:inventory.transfer');
        Route::get('stock-transfers/{stockTransfer}', [StockTransferController::class, 'show'])
            ->middleware('permission:inventory.view');
        Route::post('stock-transfers/{stockTransfer}/confirm', [StockTransferController::class, 'confirm'])
            ->middleware('permission:inventory.transfer');
        Route::post('stock-transfers/{stockTransfer}/complete', [StockTransferController::class, 'complete'])
            ->middleware('permission:inventory.transfer');

        Route::get('stock-adjustments', [StockAdjustmentController::class, 'index'])
            ->middleware('permission:inventory.view');
        Route::post('stock-adjustments', [StockAdjustmentController::class, 'store'])
            ->middleware('permission:inventory.adjust');
        Route::get('stock-adjustments/{stockAdjustment}', [StockAdjustmentController::class, 'show'])
            ->middleware('permission:inventory.view');
        Route::post('stock-adjustments/{stockAdjustment}/confirm', [StockAdjustmentController::class, 'confirm'])
            ->middleware('permission:inventory.adjust');
        Route::post('stock-adjustments/{stockAdjustment}/complete', [StockAdjustmentController::class, 'complete'])
            ->middleware('permission:inventory.adjust');

        Route::get('inventory-counts', [InventoryCountController::class, 'index'])
            ->middleware('permission:inventory.view');
        Route::post('inventory-counts/opening', [InventoryCountController::class, 'open'])
            ->middleware('permission:inventory.adjust');
        Route::get('warehouses/{warehouse}/opening-opened', [InventoryCountController::class, 'openedProducts'])
            ->middleware('permission:inventory.view');
        Route::post('inventory-counts/full', [InventoryCountController::class, 'startFull'])
            ->middleware('permission:inventory.count.create,inventory.adjust');
        Route::post('inventory-counts/spot', [InventoryCountController::class, 'startSpot'])
            ->middleware('permission:inventory.count.create,inventory.adjust');
        Route::post('inventory-counts/cycle', [InventoryCountController::class, 'planCycle'])
            ->middleware('permission:inventory.count.create,inventory.adjust');
        Route::get('inventory-counts/cycle/suggestions', [InventoryCountController::class, 'suggestCycle'])
            ->middleware('permission:inventory.view');
        Route::get('inventory-counts/cycle/dashboard', [InventoryCountController::class, 'cycleDashboard'])
            ->middleware('permission:inventory.view');
        Route::post('inventory-counts/cycle/generate', [InventoryCountController::class, 'generateCycle'])
            ->middleware('permission:inventory.cycle.configure,inventory.adjust');
        Route::patch('inventory-cycle/rules', [InventoryCountController::class, 'saveCycleRules'])
            ->middleware('permission:inventory.cycle.configure,inventory.adjust');
        Route::get('products/{product}/cycle-history', [InventoryCountController::class, 'cycleHistory'])
            ->middleware('permission:inventory.view');
        Route::post('inventory-counts', [InventoryCountController::class, 'store'])
            ->middleware('permission:inventory.adjust');
        Route::get('warehouses/{warehouse}/stock-ledger', [InventoryCountController::class, 'ledger'])
            ->middleware('permission:inventory.view');
        Route::get('inventory-counts/{inventoryCount}', [InventoryCountController::class, 'show'])
            ->middleware('permission:inventory.view');
        Route::patch('inventory-counts/{inventoryCount}', [InventoryCountController::class, 'update'])
            ->middleware('permission:inventory.adjust');
        Route::post('inventory-counts/{inventoryCount}/confirm', [InventoryCountController::class, 'confirm'])
            ->middleware('permission:inventory.adjust');
        Route::post('inventory-counts/{inventoryCount}/start', [InventoryCountController::class, 'startCycle'])
            ->middleware('permission:inventory.count.enter,inventory.adjust');
        Route::patch('inventory-counts/{inventoryCount}/lines', [InventoryCountController::class, 'saveFullLines'])
            ->middleware('permission:inventory.count.enter,inventory.adjust');
        Route::post('inventory-counts/{inventoryCount}/submit', [InventoryCountController::class, 'submitFull'])
            ->middleware('permission:inventory.count.enter,inventory.count.review,inventory.adjust');
        Route::post('inventory-counts/{inventoryCount}/review', [InventoryCountController::class, 'reviewFull'])
            ->middleware('permission:inventory.count.review,inventory.adjust');
        Route::post('inventory-counts/{inventoryCount}/approve', [InventoryCountController::class, 'approveFull'])
            ->middleware('permission:inventory.count.approve,inventory.adjust');
        Route::post('inventory-counts/{inventoryCount}/cancel', [InventoryCountController::class, 'cancelFull'])
            ->middleware('permission:inventory.count.approve,inventory.adjust');
        Route::post('inventory-counts/{inventoryCount}/complete', [InventoryCountController::class, 'complete'])
            ->middleware('permission:inventory.adjust');

        Route::get('products/{product}/batches', [BatchController::class, 'index'])
            ->middleware('permission:inventory.view');
        Route::post('products/{product}/batches', [BatchController::class, 'store'])
            ->middleware('permission:inventory.manage');
        Route::get('batches/{batch}', [BatchController::class, 'show'])
            ->middleware('permission:inventory.view');
        Route::post('batches/{batch}/receive', [BatchController::class, 'receive'])
            ->middleware('permission:inventory.manage');
        Route::post('products/{product}/batches/preview-allocation', [BatchController::class, 'previewAllocation'])
            ->middleware('permission:inventory.view');

        // Serial numbers
        Route::get('serial-numbers/statuses', [SerialNumberController::class, 'statuses'])
            ->middleware('permission:inventory.view');
        Route::get('serial-numbers', [SerialNumberController::class, 'index'])
            ->middleware('permission:inventory.view');
        Route::post('serial-numbers', [SerialNumberController::class, 'store'])
            ->middleware('permission:inventory.manage');
        Route::get('serial-numbers/{serialNumber}', [SerialNumberController::class, 'show'])
            ->middleware('permission:inventory.view');
        Route::patch('serial-numbers/{serialNumber}', [SerialNumberController::class, 'update'])
            ->middleware('permission:inventory.manage');
        Route::delete('serial-numbers/{serialNumber}', [SerialNumberController::class, 'destroy'])
            ->middleware('permission:inventory.manage');

        // Inventory alerts (Phase 12 — MOD-BATCH)
        Route::get('inventory/alert-types', [InventoryAlertController::class, 'types'])
            ->middleware('permission:inventory.view');
        Route::get('inventory/alerts', [InventoryAlertController::class, 'index'])
            ->middleware('permission:inventory.view');
        Route::post('inventory/alerts/refresh', [InventoryAlertController::class, 'refresh'])
            ->middleware('permission:inventory.manage');
        Route::get('inventory/alerts/{inventoryAlert}', [InventoryAlertController::class, 'show'])
            ->middleware('permission:inventory.view');
        Route::post('inventory/alerts/{inventoryAlert}/acknowledge', [InventoryAlertController::class, 'acknowledge'])
            ->middleware('permission:inventory.manage');
        Route::post('inventory/alerts/{inventoryAlert}/resolve', [InventoryAlertController::class, 'resolve'])
            ->middleware('permission:inventory.manage');

        // Suppliers (Phase 13 — MOD-SUPPLIER)
        Route::get('suppliers/transaction-types', [SupplierTransactionController::class, 'types'])
            ->middleware('permission:suppliers.view');
        Route::get('suppliers/payment-methods', [SupplierPaymentController::class, 'methods'])
            ->middleware('permission:suppliers.view');
        Route::get('suppliers', [SupplierController::class, 'index'])
            ->middleware('permission:suppliers.view');
        Route::post('suppliers', [SupplierController::class, 'store'])
            ->middleware('permission:suppliers.manage');
        Route::get('suppliers/{supplier}', [SupplierController::class, 'show'])
            ->middleware('permission:suppliers.view');
        Route::patch('suppliers/{supplier}', [SupplierController::class, 'update'])
            ->middleware('permission:suppliers.manage');
        Route::delete('suppliers/{supplier}', [SupplierController::class, 'destroy'])
            ->middleware('permission:suppliers.manage');
        Route::get('suppliers/{supplier}/summary', [SupplierController::class, 'summary'])
            ->middleware('permission:suppliers.view');
        Route::get('suppliers/{supplier}/statement', [SupplierController::class, 'statement'])
            ->middleware('permission:suppliers.view');
        Route::get('suppliers/{supplier}/due-dates', [SupplierController::class, 'dueDates'])
            ->middleware('permission:suppliers.view');
        Route::get('suppliers/{supplier}/purchases', [SupplierController::class, 'purchaseHistory'])
            ->middleware('permission:suppliers.view');

        // Expenses
        Route::get('expenses/dashboard', [ExpenseController::class, 'dashboard'])
            ->middleware('permission:expenses.view,purchases.view');
        Route::get('expenses/report', [ExpenseController::class, 'report'])
            ->middleware('permission:expenses.view,purchases.view');
        Route::get('expenses/categories', [ExpenseController::class, 'categories'])
            ->middleware('permission:expenses.view,purchases.view');
        Route::post('expenses/categories', [ExpenseController::class, 'storeCategory'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::patch('expense-categories/{expenseCategory}', [ExpenseController::class, 'updateCategory'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::get('expenses/recurring', [ExpenseController::class, 'recurring'])
            ->middleware('permission:expenses.view,purchases.view');
        Route::post('expenses/recurring', [ExpenseController::class, 'storeRecurring'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::patch('recurring-expenses/{recurringExpense}', [ExpenseController::class, 'updateRecurring'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::post('expenses/recurring/generate', [ExpenseController::class, 'generate'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::get('expenses/approval-rules', [ExpenseController::class, 'rules'])
            ->middleware('permission:expenses.view,purchases.view');
        Route::post('expenses/approval-rules', [ExpenseController::class, 'storeRule'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::get('expenses/budgets', [ExpenseController::class, 'budgets'])
            ->middleware('permission:expenses.view,purchases.view');
        Route::post('expenses/budgets', [ExpenseController::class, 'storeBudget'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::get('expenses', [ExpenseController::class, 'index'])
            ->middleware('permission:expenses.view,purchases.view');
        Route::post('expenses', [ExpenseController::class, 'store'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::get('expenses/{expense}', [ExpenseController::class, 'show'])
            ->middleware('permission:expenses.view,purchases.view');
        Route::patch('expenses/{expense}', [ExpenseController::class, 'update'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::post('expenses/{expense}/submit', [ExpenseController::class, 'submit'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::post('expenses/{expense}/decide', [ExpenseController::class, 'decide'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::post('expenses/{expense}/pay', [ExpenseController::class, 'pay'])
            ->middleware('permission:expenses.manage,purchases.manage');
        Route::post('expenses/{expense}/cancel', [ExpenseController::class, 'cancel'])
            ->middleware('permission:expenses.manage,purchases.manage');

        // Purchase cycle
        Route::get('purchases/overview', [PurchaseCycleController::class, 'overview'])
            ->middleware('permission:purchases.view');
        Route::get('purchase-requisitions', [PurchaseCycleController::class, 'requisitions'])
            ->middleware('permission:purchases.view');
        Route::post('purchase-requisitions', [PurchaseCycleController::class, 'storeRequisition'])
            ->middleware('permission:purchases.manage');
        Route::get('purchase-requisitions/{purchaseRequisition}', [PurchaseCycleController::class, 'showRequisition'])
            ->middleware('permission:purchases.view');
        Route::post('purchase-requisitions/{purchaseRequisition}/act', [PurchaseCycleController::class, 'actRequisition'])
            ->middleware('permission:purchases.manage');
        Route::post('purchase-requisitions/{purchaseRequisition}/convert', [PurchaseCycleController::class, 'convertRequisition'])
            ->middleware('permission:purchases.manage');
        Route::get('purchase-proformas', [PurchaseCycleController::class, 'proformas'])
            ->middleware('permission:purchases.view');
        Route::post('purchase-proformas', [PurchaseCycleController::class, 'storeProforma'])
            ->middleware('permission:purchases.manage');
        Route::get('purchase-proformas/{purchaseProforma}', [PurchaseCycleController::class, 'showProforma'])
            ->middleware('permission:purchases.view');
        Route::post('purchase-proformas/{purchaseProforma}/act', [PurchaseCycleController::class, 'actProforma'])
            ->middleware('permission:purchases.manage');
        Route::post('purchase-proformas/{purchaseProforma}/convert', [PurchaseCycleController::class, 'convertProforma'])
            ->middleware('permission:purchases.manage');
        Route::get('purchase-returns', [PurchaseCycleController::class, 'returns'])
            ->middleware('permission:purchases.view');
        Route::post('purchase-returns', [PurchaseCycleController::class, 'storeReturn'])
            ->middleware('permission:purchases.manage');
        Route::get('purchase-returns/{purchaseReturn}', [PurchaseCycleController::class, 'showReturn'])
            ->middleware('permission:purchases.view');
        Route::post('purchase-returns/{purchaseReturn}/act', [PurchaseCycleController::class, 'actReturn'])
            ->middleware('permission:purchases.manage');

        // Purchases (Phase 14 — MOD-PURCHASE)
        Route::get('purchase-orders/statuses', [PurchaseOrderController::class, 'statuses'])
            ->middleware('permission:purchases.view');
        Route::get('purchase-orders', [PurchaseOrderController::class, 'index'])
            ->middleware('permission:purchases.view,inventory.view');
        Route::post('purchase-orders', [PurchaseOrderController::class, 'store'])
            ->middleware('permission:purchases.manage,inventory.manage');
        Route::get('purchase-orders/{purchaseOrder}', [PurchaseOrderController::class, 'show'])
            ->middleware('permission:purchases.view');
        Route::patch('purchase-orders/{purchaseOrder}', [PurchaseOrderController::class, 'update'])
            ->middleware('permission:purchases.manage');
        Route::post('purchase-orders/{purchaseOrder}/confirm', [PurchaseOrderController::class, 'confirm'])
            ->middleware('permission:purchases.manage,inventory.manage');
        Route::post('purchase-orders/{purchaseOrder}/submit', [PurchaseOrderController::class, 'submit'])
            ->middleware('permission:purchases.manage');
        Route::post('purchase-orders/{purchaseOrder}/approve', [PurchaseOrderController::class, 'approve'])
            ->middleware('permission:purchases.manage');
        Route::post('purchase-orders/{purchaseOrder}/cancel', [PurchaseOrderController::class, 'cancel'])
            ->middleware('permission:purchases.manage');
        Route::post('purchase-orders/{purchaseOrder}/receive', [PurchaseOrderController::class, 'receive'])
            ->middleware('permission:purchases.receive');
        Route::get('goods-receipts/{goodsReceipt}', [GoodsReceiptController::class, 'show'])
            ->middleware('permission:purchases.view');
        Route::get('purchase-invoices', [PurchaseInvoiceController::class, 'index'])
            ->middleware('permission:purchases.view');
        Route::get('purchase-invoices/{purchaseInvoice}', [PurchaseInvoiceController::class, 'show'])
            ->middleware('permission:purchases.view');
        Route::post('purchase-invoices/{purchaseInvoice}/payments', [PurchasePaymentController::class, 'store'])
            ->middleware('permission:purchases.manage');

        Route::get('suppliers/{supplier}/contacts', [SupplierContactController::class, 'index'])
            ->middleware('permission:suppliers.view');
        Route::post('suppliers/{supplier}/contacts', [SupplierContactController::class, 'store'])
            ->middleware('permission:suppliers.manage');
        Route::patch('supplier-contacts/{supplierContact}', [SupplierContactController::class, 'update'])
            ->middleware('permission:suppliers.manage');
        Route::delete('supplier-contacts/{supplierContact}', [SupplierContactController::class, 'destroy'])
            ->middleware('permission:suppliers.manage');

        Route::get('suppliers/{supplier}/transactions', [SupplierTransactionController::class, 'index'])
            ->middleware('permission:suppliers.view');
        Route::post('suppliers/{supplier}/transactions', [SupplierTransactionController::class, 'store'])
            ->middleware('permission:suppliers.manage');
        Route::post('suppliers/{supplier}/credit-notes', [SupplierTransactionController::class, 'storeCreditNote'])
            ->middleware('permission:suppliers.manage');

        Route::get('suppliers/{supplier}/payments', [SupplierPaymentController::class, 'index'])
            ->middleware('permission:suppliers.view');
        Route::post('suppliers/{supplier}/payments', [SupplierPaymentController::class, 'store'])
            ->middleware('permission:suppliers.manage');
        Route::get('supplier-payments/{supplierPayment}', [SupplierPaymentController::class, 'show'])
            ->middleware('permission:suppliers.view');

        // Payables (Phase 30 — MOD-PAYABLE)
        Route::get('payables/summary', [PayableController::class, 'summary'])
            ->middleware('permission:suppliers.view');
        Route::get('payables/schedule', [PayableController::class, 'schedule'])
            ->middleware('permission:suppliers.view');
        Route::get('payables/payments', [PayableController::class, 'payments'])
            ->middleware('permission:suppliers.view');

        // Customers (Phase 15 — MOD-CUSTOMER)
        Route::get('customers/transaction-types', [CustomerTransactionController::class, 'types'])
            ->middleware('permission:customers.view');
        Route::get('customers/payment-methods', [CustomerPaymentController::class, 'methods'])
            ->middleware('permission:customers.view');
        Route::get('customers', [CustomerController::class, 'index'])
            ->middleware('permission:customers.view');
        Route::post('customers', [CustomerController::class, 'store'])
            ->middleware('permission:customers.manage');
        Route::get('customers/{customer}', [CustomerController::class, 'show'])
            ->middleware('permission:customers.view');
        Route::patch('customers/{customer}', [CustomerController::class, 'update'])
            ->middleware('permission:customers.manage');
        Route::delete('customers/{customer}', [CustomerController::class, 'destroy'])
            ->middleware('permission:customers.manage');
        Route::get('customers/{customer}/summary', [CustomerController::class, 'summary'])
            ->middleware('permission:customers.view');
        Route::get('customers/{customer}/balance', [CustomerController::class, 'balance'])
            ->middleware('permission:customers.view');
        Route::get('customers/{customer}/history', [CustomerController::class, 'history'])
            ->middleware('permission:customers.view');
        Route::get('customers/{customer}/sales', [CustomerController::class, 'salesHistory'])
            ->middleware('permission:customers.view');
        Route::get('customers/{customer}/loyalty', [CustomerController::class, 'loyalty'])
            ->middleware('permission:customers.view');
        Route::post('customers/{customer}/loyalty/redeem', [CustomerController::class, 'redeemLoyalty'])
            ->middleware('permission:customers.manage');

        Route::get('customers/{customer}/addresses', [CustomerAddressController::class, 'index'])
            ->middleware('permission:customers.view');
        Route::post('customers/{customer}/addresses', [CustomerAddressController::class, 'store'])
            ->middleware('permission:customers.manage');
        Route::patch('customer-addresses/{customerAddress}', [CustomerAddressController::class, 'update'])
            ->middleware('permission:customers.manage');
        Route::delete('customer-addresses/{customerAddress}', [CustomerAddressController::class, 'destroy'])
            ->middleware('permission:customers.manage');

        Route::get('customers/{customer}/transactions', [CustomerTransactionController::class, 'index'])
            ->middleware('permission:customers.view');
        Route::post('customers/{customer}/transactions', [CustomerTransactionController::class, 'store'])
            ->middleware('permission:customers.manage');
        Route::post('customers/{customer}/sale-returns', [CustomerTransactionController::class, 'storeSaleReturn'])
            ->middleware('permission:customers.manage');
        Route::post('customers/{customer}/credit-notes', [CustomerTransactionController::class, 'storeCreditNote'])
            ->middleware('permission:customers.manage');

        Route::get('customers/{customer}/payments', [CustomerPaymentController::class, 'index'])
            ->middleware('permission:customers.view');
        Route::post('customers/{customer}/payments', [CustomerPaymentController::class, 'store'])
            ->middleware('permission:customers.manage');
        Route::get('customer-payments/{customerPayment}', [CustomerPaymentController::class, 'show'])
            ->middleware('permission:customers.view');

        Route::post('sync/push', [SyncController::class, 'push'])
            ->middleware('permission:sales.create');
        Route::get('sync/pull', [SyncController::class, 'pull'])
            ->middleware('permission:sales.view');
        Route::get('sync/status', [SyncController::class, 'status'])
            ->middleware('permission:sales.view');
        Route::post('sync/ack', [SyncController::class, 'ack'])
            ->middleware('permission:sales.create');
        Route::post('sync/heartbeat', [SyncController::class, 'heartbeat'])
            ->middleware('permission:sales.create');

        // POS Core (Phase 16 — MOD-POS)
        Route::get('stores/{store}/pos/overview', [PosController::class, 'overview'])
            ->middleware('permission:sales.view');
        Route::get('stores/{store}/pos/catalog', [PosController::class, 'catalog'])
            ->middleware('permission:sales.view');
        Route::get('stores/{store}/pos/categories', [PosController::class, 'categories'])
            ->middleware('permission:sales.view');
        Route::get('stores/{store}/pos/products', [PosController::class, 'products'])
            ->middleware('permission:sales.view');
        Route::get('stores/{store}/pos/session', [PosController::class, 'session'])
            ->middleware('permission:sales.view,sales.create');
        Route::post('stores/{store}/pos/unlock', [PosController::class, 'unlock'])
            ->middleware('permission:sales.create');
        Route::post('stores/{store}/pos/shifts/open', [PosController::class, 'openShift'])
            ->middleware('permission:sales.create');
        Route::post('stores/{store}/pos/shifts/close', [PosController::class, 'closeShift'])
            ->middleware('permission:sales.create');
        Route::post('stores/{store}/pos/sales/{sale}/refund', [PosController::class, 'refundSale'])
            ->middleware('permission:sales.create');

        Route::post('stores/{store}/cart/calculate', [CartController::class, 'calculate'])
            ->middleware('permission:sales.create');

        // Sales Engine (Phase 24 — MOD-SALES)
        Route::get('stores/{store}/pos/reservations', [PosReservationController::class, 'index'])
            ->middleware('permission:sales.view');
        Route::post('stores/{store}/pos/reservations', [PosReservationController::class, 'store'])
            ->middleware('permission:sales.create');
        Route::patch('pos-reservations/{posReservation}', [PosReservationController::class, 'update'])
            ->middleware('permission:sales.create');
        Route::patch('pos-reservations/{posReservation}/status', [PosReservationController::class, 'updateStatus'])
            ->middleware('permission:sales.create');

        Route::get('stores/{store}/sales', [SaleController::class, 'index'])
            ->middleware('permission:sales.view');
        Route::get('stores/{store}/sales/export', [SaleController::class, 'export'])
            ->middleware('permission:sales.view');
        Route::post('stores/{store}/sales', [SaleController::class, 'store'])
            ->middleware('permission:sales.create');
        Route::post('stores/{store}/sales/holds', [SaleController::class, 'hold'])
            ->middleware('permission:sales.create');
        Route::get('sales/{sale}', [SaleController::class, 'show'])
            ->middleware('permission:sales.view');
        Route::put('sales/{sale}', [SaleController::class, 'update'])
            ->middleware('permission:sales.create');
        Route::delete('sales/{sale}', [SaleController::class, 'destroy'])
            ->middleware('permission:sales.create');
        Route::get('stores/{store}/sale-returns', [SaleReturnController::class, 'indexForStore'])
            ->middleware('permission:sales.view');

        // Sale Returns (Phase 27 — MOD-RETURN)
        Route::get('returns/reasons', [SaleReturnController::class, 'reasons'])
            ->middleware('permission:sales.view');
        Route::get('sales/{sale}/returns', [SaleReturnController::class, 'index'])
            ->middleware('permission:sales.view');
        Route::post('sales/{sale}/returns', [SaleReturnController::class, 'store'])
            ->middleware('permission:sales.return');
        Route::get('sale-returns/{saleReturn}', [SaleReturnController::class, 'show'])
            ->middleware('permission:sales.view');

        // Refunds (Phase 28 — MOD-REFUND)
        Route::get('refunds/methods', [RefundController::class, 'methods'])
            ->middleware('permission:sales.view');
        Route::get('sale-refunds/{saleRefund}', [RefundController::class, 'show'])
            ->middleware('permission:sales.view');

        // Receipts & Invoices (Phase 26 — MOD-RECEIPT)
        Route::get('receipt-formats', [SaleReceiptController::class, 'formats'])
            ->middleware('permission:sales.view');
        Route::get('sales/{sale}/receipt', [SaleReceiptController::class, 'show'])
            ->middleware('permission:sales.view');
        Route::post('sales/{sale}/receipt', [SaleReceiptController::class, 'store'])
            ->middleware('permission:sales.create');
        Route::get('sales/{sale}/receipts', [SaleReceiptController::class, 'index'])
            ->middleware('permission:sales.view');
        Route::get('sales/{sale}/invoice', [SaleInvoiceController::class, 'show'])
            ->middleware('permission:sales.view');
        Route::post('sales/{sale}/invoice', [SaleInvoiceController::class, 'store'])
            ->middleware('permission:sales.create');
        Route::get('sales/{sale}/invoices', [SaleInvoiceController::class, 'index'])
            ->middleware('permission:sales.view');
        Route::post('sale-invoices/{invoice}/cancel', [SaleInvoiceController::class, 'cancel'])
            ->middleware('permission:sales.create');

        // Payment Engine (Phase 22 — MOD-PAYMENT)
        Route::get('payments/methods', [PaymentController::class, 'methods'])
            ->middleware('permission:sales.view');
        Route::post('stores/{store}/payments/validate', [PaymentController::class, 'validate'])
            ->middleware('permission:sales.create');
        Route::post('stores/{store}/payments/process', [PaymentController::class, 'process'])
            ->middleware('permission:sales.create');
        Route::get('payment-transactions/{paymentTransaction}', [PaymentController::class, 'show'])
            ->middleware('permission:sales.view');
    });
});
