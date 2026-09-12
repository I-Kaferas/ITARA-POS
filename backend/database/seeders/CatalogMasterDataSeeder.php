<?php

namespace Database\Seeders;

use App\Models\Brand;
use App\Models\Tax;
use App\Models\Tenant;
use App\Models\Unit;
use Illuminate\Database\Seeder;

class CatalogMasterDataSeeder extends Seeder
{
    public function run(): void
    {
        $tenant = Tenant::query()->where('slug', 'demo')->first();

        if (! $tenant) {
            return;
        }

        $units = [
            ['code' => 'piece', 'name' => 'Pièce', 'symbol' => 'pc', 'is_fractional' => false],
            ['code' => 'kg', 'name' => 'Kilogramme', 'symbol' => 'kg', 'is_fractional' => true],
            ['code' => 'g', 'name' => 'Gramme', 'symbol' => 'g', 'is_fractional' => true],
            ['code' => 'L', 'name' => 'Litre', 'symbol' => 'L', 'is_fractional' => true],
            ['code' => 'h', 'name' => 'Heure', 'symbol' => 'h', 'is_fractional' => true],
        ];

        foreach ($units as $unit) {
            Unit::query()->firstOrCreate(
                ['tenant_id' => $tenant->id, 'code' => $unit['code']],
                [...$unit, 'tenant_id' => $tenant->id, 'is_active' => true],
            );
        }

        Tax::query()->firstOrCreate(
            ['tenant_id' => $tenant->id, 'code' => 'TVA18'],
            [
                'tenant_id' => $tenant->id,
                'name' => 'TVA 18%',
                'rate' => 18,
                'is_inclusive' => false,
                'is_active' => true,
            ],
        );

        Brand::query()->firstOrCreate(
            ['tenant_id' => $tenant->id, 'slug' => 'generique'],
            [
                'tenant_id' => $tenant->id,
                'name' => 'Générique',
                'description' => 'Marque par défaut',
                'is_active' => true,
            ],
        );
    }
}
