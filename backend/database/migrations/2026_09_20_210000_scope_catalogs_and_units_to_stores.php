<?php

use App\Models\Catalog;
use App\Models\Store;
use App\Models\Unit;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('catalogs', function (Blueprint $table) {
            $table->foreignUuid('store_id')
                ->nullable()
                ->after('company_id')
                ->constrained('stores')
                ->nullOnDelete();
            $table->unique('store_id');
        });

        Schema::table('units', function (Blueprint $table) {
            $table->foreignUuid('store_id')
                ->nullable()
                ->after('tenant_id')
                ->constrained('stores')
                ->cascadeOnDelete();
            $table->dropUnique(['tenant_id', 'code']);
            $table->unique(['tenant_id', 'store_id', 'code']);
            $table->index(['tenant_id', 'store_id', 'is_active']);
        });

        Schema::table('products', function (Blueprint $table) {
            $table->dropUnique(['tenant_id', 'sku']);
            $table->unique(['catalog_id', 'sku']);
        });

        $this->backfillStoreCatalogsAndUnits();
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropUnique(['catalog_id', 'sku']);
            $table->unique(['tenant_id', 'sku']);
        });

        Schema::table('units', function (Blueprint $table) {
            $table->dropUnique(['tenant_id', 'store_id', 'code']);
            $table->dropIndex(['tenant_id', 'store_id', 'is_active']);
            $table->dropConstrainedForeignId('store_id');
            $table->unique(['tenant_id', 'code']);
        });

        Schema::table('catalogs', function (Blueprint $table) {
            $table->dropUnique(['store_id']);
            $table->dropConstrainedForeignId('store_id');
        });
    }

    private function backfillStoreCatalogsAndUnits(): void
    {
        $defaultUnits = [
            ['code' => 'piece', 'name' => 'Pièce', 'symbol' => 'pc', 'is_fractional' => false],
            ['code' => 'kg', 'name' => 'Kilogramme', 'symbol' => 'kg', 'is_fractional' => true],
            ['code' => 'g', 'name' => 'Gramme', 'symbol' => 'g', 'is_fractional' => true],
            ['code' => 'L', 'name' => 'Litre', 'symbol' => 'L', 'is_fractional' => true],
            ['code' => 'h', 'name' => 'Heure', 'symbol' => 'h', 'is_fractional' => true],
        ];

        $stores = Store::query()->with('branch')->orderBy('created_at')->get();
        $claimedCompanies = [];

        foreach ($stores as $store) {
            $companyId = $store->branch?->company_id;
            if (! $companyId) {
                continue;
            }

            $catalog = Catalog::query()->where('store_id', $store->id)->first();
            if (! $catalog) {
                $legacy = null;
                if (! isset($claimedCompanies[$companyId])) {
                    $legacy = Catalog::query()
                        ->where('company_id', $companyId)
                        ->whereNull('store_id')
                        ->orderByDesc('is_default')
                        ->orderBy('created_at')
                        ->first();
                }

                if ($legacy) {
                    $legacy->update([
                        'store_id' => $store->id,
                        'name' => $legacy->name ?: "Catalogue · {$store->name}",
                        'is_default' => true,
                    ]);
                    $claimedCompanies[$companyId] = true;
                    $catalog = $legacy;
                } else {
                    $catalog = Catalog::query()->create([
                        'tenant_id' => $store->tenant_id,
                        'company_id' => $companyId,
                        'store_id' => $store->id,
                        'name' => "Catalogue · {$store->name}",
                        'description' => "Catalogue du magasin {$store->name}",
                        'is_default' => true,
                        'is_active' => true,
                    ]);
                }
            }

            foreach ($defaultUnits as $unit) {
                $exists = Unit::query()
                    ->where('tenant_id', $store->tenant_id)
                    ->where('store_id', $store->id)
                    ->where('code', $unit['code'])
                    ->exists();

                if ($exists) {
                    continue;
                }

                $shared = Unit::query()
                    ->where('tenant_id', $store->tenant_id)
                    ->whereNull('store_id')
                    ->where('code', $unit['code'])
                    ->first();

                if ($shared) {
                    $shared->update(['store_id' => $store->id]);
                    continue;
                }

                Unit::query()->create([
                    'tenant_id' => $store->tenant_id,
                    'store_id' => $store->id,
                    'code' => $unit['code'],
                    'name' => $unit['name'],
                    'symbol' => $unit['symbol'],
                    'is_fractional' => $unit['is_fractional'],
                    'is_active' => true,
                ]);
            }
        }

        // Any remaining shared units without a store stay as templates (ignored by store APIs).
        unset($claimedCompanies);
    }
};
