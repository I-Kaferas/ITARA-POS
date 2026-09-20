<?php

namespace Database\Seeders;

use App\Models\Branch;
use App\Models\Catalog;
use App\Models\Category;
use App\Models\Company;
use App\Models\Currency;
use App\Models\CashRegister;
use App\Models\Price;
use App\Models\Product;
use App\Models\Promotion;
use App\Models\PromotionItem;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseOrder;
use App\Models\PurchaseOrderItem;
use App\Models\Role;
use App\Models\Store;
use App\Models\Supplier;
use App\Models\Tenant;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\Organization\CompanyTaxDefaults;
use App\Services\Payments\CompanyPaymentMethodService;
use App\Enums\InventoryMovementType;
use App\Enums\PurchaseInvoiceStatus;
use App\Enums\PurchaseOrderStatus;
use App\Enums\SupplierTransactionType;
use App\Services\Inventory\InventoryMovementService;
use App\Services\Catalog\ProductImageService;
use App\Services\Catalog\StoreCatalogService;
use App\Services\Supplier\SupplierLedgerService;
use Illuminate\Database\Seeder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            PermissionSeeder::class,
        ]);

        $tenant = Tenant::create([
            'name' => 'Demo Boutique',
            'slug' => 'demo',
            'status' => 'active',
            'settings' => \App\Support\TenantBranding::demoSettings('Demo Boutique'),
        ]);

        $this->call(RoleSeeder::class);

        $admin = User::query()->updateOrCreate(
            ['email' => 'admin@pos.local'],
            [
                'tenant_id' => $tenant->id,
                'name' => 'Administrateur',
                'phone' => '+25760000000',
                'pin' => '0000',
                'password' => Hash::make('password'),
                'is_active' => true,
            ],
        );

        $adminRole = Role::query()
            ->where('tenant_id', $tenant->id)
            ->where('slug', 'administrator')
            ->first();

        if ($adminRole) {
            $admin->roles()->syncWithoutDetaching([
                $adminRole->id => ['branch_id' => null, 'store_id' => null],
            ]);
        }
        $company = Company::create([
            'tenant_id' => $tenant->id,
            'name' => 'Ma Boutique',
            'trade_name' => 'Ma Boutique',
            'legal_name' => 'Ma Boutique SARL',
            'legal_form' => 'SARL',
            'tax_id' => 'NIF-DEMO-001',
            'registration_number' => 'RC-BJM-001',
            'phone' => '+25722200000',
            'email' => 'contact@maboutique.local',
            'website' => 'https://maboutique.local',
            'currency_code' => 'FBU',
            'locale' => 'fr',
            'timezone' => 'Africa/Bujumbura',
            'address' => [
                'street' => 'Avenue de l\'Indépendance',
                'city' => 'Bujumbura',
                'state' => 'Bujumbura Mairie',
                'postal_code' => '',
                'country' => 'Burundi',
            ],
            'settings' => [
                'timezone' => 'Africa/Bujumbura',
                'locale' => 'fr',
                'receipt_footer' => 'Merci de votre visite',
                'legal_mentions' => 'NIF-DEMO-001 · RC-BJM-001',
                'vat_registered' => true,
            ],
            'is_active' => true,
        ]);

        app(CompanyPaymentMethodService::class)->ensureDefaults($company);
        app(CompanyTaxDefaults::class)->ensure($tenant->id);

        Currency::create([
            'tenant_id' => $tenant->id,
            'code' => 'FBU',
            'name' => 'Franc Burundais',
            'symbol' => 'FBu',
            'decimal_places' => 0,
            'exchange_rate' => 1,
            'is_default' => true,
            'is_active' => true,
        ]);

        Currency::create([
            'tenant_id' => $tenant->id,
            'code' => 'USD',
            'name' => 'Dollar américain',
            'symbol' => '$',
            'decimal_places' => 2,
            'exchange_rate' => 1,
            'is_default' => false,
            'is_active' => true,
        ]);

        Currency::create([
            'tenant_id' => $tenant->id,
            'code' => 'EUR',
            'name' => 'Euro',
            'symbol' => '€',
            'decimal_places' => 2,
            'exchange_rate' => 1,
            'is_default' => false,
            'is_active' => true,
        ]);

        $catalog = Catalog::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'Catalogue principal',
            'description' => 'Catalogue central de tous les produits',
            'is_default' => true,
            'is_active' => true,
        ]);

        $branch = Branch::create([
            'tenant_id' => $tenant->id,
            'company_id' => $company->id,
            'name' => 'Siège',
            'code' => 'HQ',
            'is_active' => true,
        ]);

        Warehouse::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Entrepôt principal',
            'code' => 'WH01',
            'is_active' => true,
        ]);

        $warehouse = Warehouse::query()->where('code', 'WH01')->first();

        $store = Store::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Magasin Centre',
            'code' => 'MC01',
            'is_active' => true,
        ]);

        $storeNord = Store::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'name' => 'Magasin Nord',
            'code' => 'MN01',
            'is_active' => true,
        ]);

        $storeCatalogs = app(StoreCatalogService::class);
        $catalog = $storeCatalogs->bootstrap($store);
        $storeCatalogs->bootstrap($storeNord);

        $category = Category::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'name' => 'Général',
            'slug' => 'general',
            'sort_order' => 0,
            'is_active' => true,
        ]);

        $productA = Product::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'category_id' => $category->id,
            'sku' => 'SKU-001',
            'name' => 'Produit démo A',
            'description' => 'Article exemple pour le backoffice',
            'base_price' => 1500,
            'cost_price' => 800,
            'is_active' => true,
        ]);

        foreach ([
            ['price_type' => 'retail', 'amount' => 1500],
            ['price_type' => 'wholesale', 'amount' => 1200],
            ['price_type' => 'vip', 'amount' => 1300],
            ['price_type' => 'distributor', 'amount' => 1000],
            ['price_type' => 'special', 'amount' => 1400],
        ] as $tier) {
            Price::create([
                'tenant_id' => $tenant->id,
                'priceable_type' => Product::class,
                'priceable_id' => $productA->id,
                ...$tier,
            ]);
        }

        $productB = Product::create([
            'tenant_id' => $tenant->id,
            'catalog_id' => $catalog->id,
            'category_id' => $category->id,
            'sku' => 'SKU-002',
            'name' => 'Produit démo B',
            'base_price' => 2500,
            'cost_price' => 1200,
            'is_active' => true,
        ]);

        foreach ([
            ['price_type' => 'retail', 'amount' => 2500],
            ['price_type' => 'wholesale', 'amount' => 2000],
            ['price_type' => 'vip', 'amount' => 2200],
            ['price_type' => 'distributor', 'amount' => 1800],
            ['price_type' => 'special', 'amount' => 2300],
        ] as $tier) {
            Price::create([
                'tenant_id' => $tenant->id,
                'priceable_type' => Product::class,
                'priceable_id' => $productB->id,
                ...$tier,
            ]);
        }

        Promotion::create([
            'tenant_id' => $tenant->id,
            'name' => 'Soldes été -15%',
            'code' => 'SUMMER15',
            'type' => 'percentage_discount',
            'discount_percent' => 15,
            'starts_at' => now()->subWeek(),
            'ends_at' => now()->addMonths(2),
            'min_quantity' => 1,
            'max_uses' => 500,
            'priority' => 10,
            'is_active' => true,
        ]);

        $bundlePromo = Promotion::create([
            'tenant_id' => $tenant->id,
            'store_id' => $store->id,
            'name' => 'Pack Duo',
            'code' => 'PACK-DUO',
            'type' => 'bundle',
            'bundle_price' => 3500,
            'min_quantity' => 1,
            'max_uses' => 100,
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addMonth(),
            'is_active' => true,
        ]);

        foreach ([$productA, $productB] as $bundleProduct) {
            PromotionItem::create([
                'promotion_id' => $bundlePromo->id,
                'product_id' => $bundleProduct->id,
                'role' => 'bundle',
                'quantity' => 1,
            ]);
        }

        foreach ([$productA, $productB] as $storeProduct) {
            $storeProduct->importToStore($store, null, true, $admin->id);
        }

        $this->seedDemoProductImage($productA, [99, 102, 241]);
        $this->seedDemoProductImage($productB, [16, 185, 129]);

        $movementService = app(InventoryMovementService::class);
        foreach ([$productA, $productB] as $stockProduct) {
            $movementService->record([
                'warehouse' => $warehouse,
                'product' => $stockProduct,
                'movement_type' => InventoryMovementType::AdjustmentIn,
                'quantity' => 100,
                'unit_cost' => $stockProduct->cost_price,
                'notes' => 'Stock initial démo',
                'performed_by' => $admin->id,
            ]);
        }

        CashRegister::create([
            'tenant_id' => $tenant->id,
            'store_id' => $store->id,
            'name' => 'Caisse principale',
            'code' => 'REG-01',
            'is_active' => true,
        ]);

        $cashier = User::query()->updateOrCreate(
            ['email' => 'cashier@pos.local'],
            [
                'tenant_id' => $tenant->id,
                'name' => 'Caissier Démo',
                'phone' => '+25760000001',
                'pin' => '1234',
                'password' => Hash::make('password'),
                'is_active' => true,
            ],
        );

        $cashierRole = Role::query()
            ->where('tenant_id', $tenant->id)
            ->where('slug', 'cashier')
            ->first();

        if ($cashierRole) {
            $cashier->roles()->syncWithoutDetaching([
                $cashierRole->id => ['branch_id' => null, 'store_id' => $store->id],
            ]);
        }

        $supplier = Supplier::create([
            'tenant_id' => $tenant->id,
            'name' => 'Fournisseur Démo',
            'code' => 'SUP-01',
            'email' => 'fournisseur@demo.local',
            'phone' => '+25760000002',
            'currency_code' => 'USD',
            'is_active' => true,
        ]);

        $purchaseOrder = PurchaseOrder::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'supplier_id' => $supplier->id,
            'warehouse_id' => $warehouse->id,
            'order_number' => 'PO-2026-001',
            'status' => PurchaseOrderStatus::Approved,
            'subtotal' => 8000,
            'tax_total' => 0,
            'total' => 8000,
            'expected_at' => now()->addWeek(),
            'created_by' => $admin->id,
            'approved_by' => $admin->id,
            'approved_at' => now(),
        ]);

        PurchaseOrderItem::create([
            'tenant_id' => $tenant->id,
            'purchase_order_id' => $purchaseOrder->id,
            'product_id' => $productA->id,
            'quantity_ordered' => 10,
            'quantity_received' => 0,
            'unit_cost' => 800,
            'line_total' => 8000,
            'sort_order' => 0,
        ]);

        PurchaseOrder::create([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'supplier_id' => $supplier->id,
            'warehouse_id' => $warehouse->id,
            'order_number' => 'PO-2026-002',
            'status' => PurchaseOrderStatus::Draft,
            'subtotal' => 5000,
            'tax_total' => 0,
            'total' => 5000,
            'created_by' => $admin->id,
        ]);

        $ledger = app(SupplierLedgerService::class);

        $openPayable = $ledger->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => 4800,
            'reference' => 'INV-2026-001',
            'description' => 'Facture fournisseur ouverte',
            'due_date' => now()->addDays(28)->toDateString(),
            'purchase_order_id' => $purchaseOrder->id,
            'recorded_by' => $admin->id,
        ]);

        PurchaseInvoice::create([
            'tenant_id' => $tenant->id,
            'purchase_order_id' => $purchaseOrder->id,
            'supplier_id' => $supplier->id,
            'supplier_transaction_id' => $openPayable->id,
            'invoice_number' => 'INV-2026-001',
            'status' => PurchaseInvoiceStatus::Posted,
            'subtotal' => 4800,
            'tax_total' => 0,
            'total' => 4800,
            'paid_amount' => 0,
            'due_date' => now()->addDays(28),
            'invoiced_at' => now()->subDays(2),
        ]);

        $overduePayable = $ledger->recordPayable($supplier, [
            'transaction_type' => SupplierTransactionType::Purchase,
            'amount' => 3200,
            'reference' => 'INV-2026-002',
            'description' => 'Facture fournisseur en retard',
            'due_date' => now()->subDays(5)->toDateString(),
            'purchase_order_id' => $purchaseOrder->id,
            'recorded_by' => $admin->id,
        ]);

        $paidInvoice = PurchaseInvoice::create([
            'tenant_id' => $tenant->id,
            'purchase_order_id' => $purchaseOrder->id,
            'supplier_id' => $supplier->id,
            'supplier_transaction_id' => $overduePayable->id,
            'invoice_number' => 'INV-2026-002',
            'status' => PurchaseInvoiceStatus::PartiallyPaid,
            'subtotal' => 3200,
            'tax_total' => 0,
            'total' => 3200,
            'paid_amount' => 1200,
            'due_date' => now()->subDays(5),
            'invoiced_at' => now()->subDay(),
        ]);

        $ledger->recordPayment(
            supplier: $supplier,
            amount: 1200,
            allocations: [
                ['transaction_id' => $overduePayable->id, 'amount' => 1200],
            ],
            reference: 'VIR-DEMO-001',
            notes: 'Paiement partiel démo',
            recordedBy: $admin->id,
        );

        $overduePayable->refresh();
        $paidInvoice->update(['paid_amount' => 1200]);
    }

    /** @param  array{0:int,1:int,2:int}  $rgb */
    private function seedDemoProductImage(Product $product, array $rgb): void
    {
        if ($product->images()->exists()) {
            return;
        }

        $tmp = tempnam(sys_get_temp_dir(), 'posimg_').'.png';
        $img = imagecreatetruecolor(320, 240);
        $bg = imagecolorallocate($img, $rgb[0], $rgb[1], $rgb[2]);
        $fg = imagecolorallocate($img, 255, 255, 255);
        imagefilledrectangle($img, 0, 0, 320, 240, $bg);
        imagestring($img, 5, 24, 110, substr($product->name, 0, 18), $fg);
        imagepng($img, $tmp);
        imagedestroy($img);

        $upload = new UploadedFile(
            $tmp,
            Str::slug($product->sku ?: $product->name).'.png',
            'image/png',
            null,
            true,
        );

        app(ProductImageService::class)->upload($product, $upload, true);
        @unlink($tmp);
    }
}
