<?php

namespace Tests\Feature\Catalog;

use App\Models\Barcode;
use App\Models\Category;
use App\Models\Product;
use App\Services\Catalog\BarcodeValidator;
use App\Support\SimpleXlsx;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class ProductSpreadsheetImportTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private const HEADER = "SKU;Nom;Description;Code-barres;Type;Prix de vente;Prix d'achat;Catégorie;Actif;Seuil stock bas";

    public function test_export_shows_prices_in_currency_units_and_readable_columns(): void
    {
        $fixture = $this->createTenantFixture('sheet-export', 'sheet-export@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $fixture['product']->update(['base_price' => 150000, 'cost_price' => 99950, 'product_type' => 'simple']);

        $response = $this->get("/api/v1/import-export/products/export?catalog_id={$fixture['catalog']->id}&format=xlsx", $headers);
        $response->assertOk();

        $path = tempnam(sys_get_temp_dir(), 'xlsx');
        file_put_contents($path, $response->getContent());
        $rows = SimpleXlsx::readRows($path);
        @unlink($path);

        $this->assertSame(['SKU', 'Nom', 'Description', 'Code-barres', 'Type', 'Prix de vente', "Prix d'achat"], array_slice($rows[0], 0, 7));
        $this->assertSame('Produit simple', $rows[1][4]);
        $this->assertSame('1500', $rows[1][5]);
        $this->assertSame('999.5', $rows[1][6]);
        $this->assertSame('Oui', $rows[1][11]);
    }

    public function test_import_creates_product_with_units_names_and_registered_barcode(): void
    {
        $fixture = $this->createTenantFixture('sheet-create', 'sheet-create@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        Category::create([
            'tenant_id' => $fixture['tenant']->id,
            'catalog_id' => $fixture['catalog']->id,
            'name' => 'Boissons',
            'slug' => 'boissons',
            'sort_order' => 1,
            'is_active' => true,
        ]);

        $result = $this->importCsv($fixture, $headers, [
            self::HEADER,
            'JUS-01;Jus mangue;Bouteille 50cl;9501234567891;Produit simple;1 500;1000,50;boissons;oui;4',
        ]);

        $this->assertSame(1, $result['created'], json_encode($result));
        $product = Product::query()->where('sku', 'JUS-01')->firstOrFail();
        $this->assertSame(150000, $product->base_price);
        $this->assertSame(100050, $product->cost_price);
        $this->assertSame('simple', $product->product_type);
        $this->assertSame('Boissons', $product->category?->name);
        $this->assertSame(4, $product->low_stock_threshold);
        $this->assertTrue(Barcode::query()->where('barcodeable_id', $product->id)->where('barcode', '9501234567891')->exists());
    }

    public function test_update_keeps_values_of_empty_cells_and_other_barcodes(): void
    {
        $fixture = $this->createTenantFixture('sheet-update', 'sheet-update@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);
        $product = $fixture['product'];
        $product->update(['description' => 'Garder', 'cost_price' => 500]);
        foreach ([['9501234567891', true], ['9501234567884', false]] as [$code, $primary]) {
            Barcode::create([
                'tenant_id' => $fixture['tenant']->id,
                'barcodeable_type' => $product->getMorphClass(),
                'barcodeable_id' => $product->id,
                'barcode' => $code,
                'type' => BarcodeValidator::detectType($code),
                'is_primary' => $primary,
            ]);
        }

        $result = $this->importCsv($fixture, $headers, [
            self::HEADER,
            "{$product->sku};;;9501234567877;;25;;;;",
        ]);

        $this->assertSame(1, $result['updated'], json_encode($result));
        $product->refresh();
        $this->assertSame('Garder', $product->description);
        $this->assertSame(500, $product->cost_price);
        $this->assertSame(2500, $product->base_price);
        $codes = Barcode::query()->where('barcodeable_id', $product->id)->pluck('is_primary', 'barcode')->all();
        $this->assertEqualsCanonicalizing(['9501234567877', '9501234567891', '9501234567884'], array_keys($codes));
        $this->assertTrue((bool) $codes['9501234567877']);
    }

    public function test_invalid_rows_are_reported_and_legacy_headers_stay_in_cents(): void
    {
        $fixture = $this->createTenantFixture('sheet-errors', 'sheet-errors@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $result = $this->importCsv($fixture, $headers, [
            self::HEADER,
            'BAD-TYPE;Article;;;standardx;100;;;;',
            'BAD-CAT;Article;;;;100;;Inconnue;;',
            'NO-PRICE;Article;;;;;;;;',
        ]);
        $this->assertSame(0, $result['created']);
        $this->assertSame(3, $result['skipped']);
        $this->assertStringContainsString('Ligne 2', $result['errors'][0]);
        $this->assertStringContainsString('inconnu', $result['errors'][0]);
        $this->assertStringContainsString('introuvable', $result['errors'][1]);
        $this->assertStringContainsString('prix de vente', $result['errors'][2]);

        $legacy = $this->importCsv($fixture, $headers, [
            'sku,name,product_type,base_price,cost_price,is_active',
            'OLD-1,Ancien export,standard,150000,90000,1',
        ]);
        $this->assertSame(1, $legacy['created'], json_encode($legacy));
        $old = Product::query()->where('sku', 'OLD-1')->firstOrFail();
        $this->assertSame(150000, $old->base_price);
        $this->assertSame('simple', $old->product_type);
    }

    /**
     * @param  array<string, mixed>  $fixture
     * @param  array<string, string>  $headers
     * @param  list<string>  $lines
     * @return array{created: int, updated: int, skipped: int, errors: list<string>}
     */
    private function importCsv(array $fixture, array $headers, array $lines): array
    {
        $file = UploadedFile::fake()->createWithContent('produits.csv', implode("\n", $lines));

        return $this->post('/api/v1/import-export/products/import', [
            'catalog_id' => $fixture['catalog']->id,
            'file' => $file,
            'update_existing' => '1',
        ], $headers)->assertOk()->json('data');
    }
}
