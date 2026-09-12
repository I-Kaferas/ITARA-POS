<?php

namespace Tests\Feature\Catalog;

use App\Models\Product;
use App\Services\Catalog\BarcodeService;
use App\Services\Catalog\BarcodeValidator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class BarcodePhase10Test extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('barcode10', 'barcode10@test.local');
    }

    public function test_barcode_types_endpoint(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->getJson('/api/v1/barcodes/types', $headers)
            ->assertOk()
            ->assertJsonFragment(['slug' => 'ean13'])
            ->assertJsonFragment(['slug' => 'qr']);
    }

    public function test_generate_and_assign_barcode_to_product(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $generated = $this->postJson('/api/v1/barcodes/generate', ['type' => 'ean13'], $headers)
            ->assertOk()
            ->json('data');

        $this->assertSame('ean13', $generated['type']);
        BarcodeValidator::validate($generated['barcode'], 'ean13');

        $product = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'BC-GEN-01',
            'name' => 'Produit généré',
            'product_type' => 'simple',
            'base_price' => 1000,
            'barcodes' => [
                ['barcode' => $generated['barcode'], 'type' => 'ean13', 'is_primary' => true],
            ],
        ], $headers)->assertCreated()->json('data');

        $this->getJson("/api/v1/products/{$product['id']}/barcodes", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_lookup_finds_product_by_exact_barcode(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];
        $store = $this->fixture['store'];

        $code = 'INT-SCAN-001';

        $product = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'BC-LOOKUP',
            'name' => 'Scan me',
            'product_type' => 'simple',
            'base_price' => 500,
            'barcodes' => [['barcode' => $code, 'type' => 'internal', 'is_primary' => true]],
        ], $headers)->assertCreated()->json('data');

        $this->postJson("/api/v1/stores/{$store->id}/products/import", [
            'product_ids' => [$product['id']],
        ], $headers)->assertCreated();

        $this->getJson('/api/v1/barcodes/lookup?code='.urlencode($code).'&store_id='.$store->id, $headers)
            ->assertOk()
            ->assertJsonPath('found', true)
            ->assertJsonPath('data.product.id', $product['id']);
    }

    public function test_search_returns_partial_matches(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'BC-SEARCH',
            'name' => 'Searchable',
            'product_type' => 'simple',
            'base_price' => 500,
            'barcodes' => [['barcode' => 'PREFIX-ABC-999', 'type' => 'code128', 'is_primary' => true]],
        ], $headers)->assertCreated();

        $this->getJson('/api/v1/barcodes/search?q=PREFIX-ABC', $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_multiple_barcodes_per_product(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $product = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'BC-MULTI',
            'name' => 'Multi barcode',
            'product_type' => 'simple',
            'base_price' => 500,
            'barcodes' => [
                ['barcode' => 'QR-PRODUCT-001', 'type' => 'qr', 'is_primary' => true],
                ['barcode' => 'C128-ALT-001', 'type' => 'code128', 'is_primary' => false],
            ],
        ], $headers)->assertCreated()->json('data');

        $this->getJson("/api/v1/products/{$product['id']}/barcodes", $headers)
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_print_payload_returns_label_data(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $product = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'BC-PRINT',
            'name' => 'Print label',
            'product_type' => 'simple',
            'base_price' => 500,
            'barcodes' => [['barcode' => 'PRINT-ME', 'type' => 'internal', 'is_primary' => true]],
        ], $headers)->assertCreated()->json('data');

        $barcodeId = $this->getJson("/api/v1/products/{$product['id']}/barcodes", $headers)
            ->json('data.0.id');

        $this->getJson("/api/v1/barcodes/{$barcodeId}/print", $headers)
            ->assertOk()
            ->assertJsonPath('data.barcode', 'PRINT-ME')
            ->assertJsonPath('data.label', 'Print label');
    }

    public function test_store_barcode_index_for_pos(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];
        $store = $this->fixture['store'];

        $product = $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'BC-POS',
            'name' => 'POS index',
            'product_type' => 'simple',
            'base_price' => 500,
            'barcodes' => [['barcode' => 'POS-IDX-1', 'type' => 'internal', 'is_primary' => true]],
        ], $headers)->assertCreated()->json('data');

        $this->postJson("/api/v1/stores/{$store->id}/products/import", [
            'product_ids' => [$product['id']],
        ], $headers)->assertCreated();

        $index = app(BarcodeService::class)->indexForStore($store);
        $this->assertNotEmpty($index);
        $this->assertSame('POS-IDX-1', $index[0]['barcode']);
    }

    public function test_ean13_invalid_checksum_rejected(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $catalog = $this->fixture['catalog'];

        $this->postJson("/api/v1/catalogs/{$catalog->id}/products", [
            'sku' => 'BC-BAD-EAN',
            'name' => 'Bad EAN',
            'product_type' => 'simple',
            'base_price' => 500,
            'barcodes' => [['barcode' => '1234567890123', 'type' => 'ean13', 'is_primary' => true]],
        ], $headers)->assertStatus(422);
    }
}
