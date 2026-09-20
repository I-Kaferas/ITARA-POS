<?php

namespace Tests\Feature\Reports;

use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class StoreStockReportTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('stkrep', 'stkrep@test.local');
    }

    public function test_store_stock_report_returns_header_and_summary(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        $product = $this->fixture['product'];
        $user = $this->fixture['user'];

        $product->update([
            'cost_price' => 500,
            'low_stock_threshold' => 10,
        ]);
        $store->users()->syncWithoutDetaching([$user->id]);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 40,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $from = now()->startOfMonth()->toDateString();
        $to = now()->toDateString();

        $this->getJson("/api/v1/reports/store-stock?store_id={$store->id}&from={$from}&to={$to}", $headers)
            ->assertOk()
            ->assertJsonPath('data.store.name', $store->name)
            ->assertJsonPath('data.store.code', $store->code)
            ->assertJsonPath('data.store.manager', $user->name)
            ->assertJsonPath('data.summary.skus_in_stock', 1)
            ->assertJsonPath('data.summary.stockouts', 0)
            ->assertJsonFragment(['sku' => $product->sku])
            ->assertJsonStructure([
                'data' => [
                    'generated_at',
                    'period' => ['from', 'to'],
                    'store' => ['id', 'name', 'code', 'address', 'manager'],
                    'summary' => [
                        'opening_value',
                        'closing_value',
                        'variation_value',
                        'variation_pct',
                        'skus_in_stock',
                        'stockouts',
                        'turnover_rate',
                    ],
                    'stock_rows',
                    'movements' => ['inbound', 'outbound', 'transfers', 'adjustments'],
                    'alerts' => ['out_of_stock', 'below_min', 'overstock', 'expiring', 'count_variances'],
                    'performance' => ['top_sold', 'least_sold', 'no_movement', 'service_rate'],
                    'comparison' => ['stores', 'best_turnover_store', 'transfer_opportunities'],
                    'recommendations' => ['reorder_urgent', 'transfer', 'threshold_adjustments'],
                ],
            ]);
    }

    public function test_store_stock_export_downloads_csv(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];

        $response = $this->get("/api/v1/reports/export/store-stock?store_id={$store->id}", $headers);

        $response->assertOk();
        $this->assertStringContainsString('text/csv', (string) $response->headers->get('content-type'));
        $this->assertStringContainsString('sku', $response->streamedContent());
    }

    public function test_low_stock_product_is_flagged(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $store = $this->fixture['store'];
        $warehouse = $this->fixture['warehouse'];
        /** @var Product $product */
        $product = $this->fixture['product'];
        $product->update(['cost_price' => 100, 'low_stock_threshold' => 20]);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 5,
            'unit_cost' => 100,
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/reports/store-stock?store_id={$store->id}", $headers)
            ->assertOk()
            ->assertJsonPath('data.summary.low_stock_count', 1)
            ->assertJsonPath('data.stock_rows.0.status', 'low');
    }
}
