<?php

namespace Tests\Feature\Performance;

use App\Enums\SalePaymentStatus;
use App\Enums\SaleStatus;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\SalePayment;
use App\Models\Store;
use App\Services\Pos\PosOverviewService;
use App\Services\Reports\ReportService;
use App\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class QueryPerformanceTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_hot_list_indexes_exist(): void
    {
        $this->assertTrue(Schema::hasIndex('sales', 'sales_store_status_completed_idx'));
        $this->assertTrue(Schema::hasIndex('products', 'products_catalog_name_idx'));
        $this->assertTrue(Schema::hasIndex('inventory_movements', 'movements_warehouse_occurred_idx'));
        $this->assertTrue(Schema::hasIndex('customers', 'customers_tenant_phone_idx'));
    }

    public function test_sales_by_store_aggregates_in_one_query(): void
    {
        $fixture = $this->createTenantFixture('perf', 'perf@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        Store::create([
            'tenant_id' => $fixture['tenant']->id,
            'branch_id' => $fixture['branch']->id,
            'name' => 'Second',
            'code' => 'PERF02',
            'is_active' => true,
        ]);

        Sale::create([
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $fixture['store']->id,
            'reference' => 'PERF-1',
            'status' => SaleStatus::Completed,
            'subtotal' => 2500,
            'total' => 2500,
            'paid_amount' => 2500,
            'payment_status' => SalePaymentStatus::Paid,
            'currency' => 'FBU',
            'completed_at' => now(),
        ]);

        DB::flushQueryLog();
        DB::enableQueryLog();

        $rows = app(ReportService::class)->salesByStore(null, null);

        $salesQueries = collect(DB::getQueryLog())->filter(
            fn (array $query) => str_contains(strtolower($query['query']), 'sales')
                && str_contains(strtolower($query['query']), 'count')
        );

        $this->assertCount(1, $salesQueries);
        $match = collect($rows)->firstWhere('store_id', $fixture['store']->id);
        $this->assertSame(1, $match['sales_count']);
        $this->assertSame(2500, $match['revenue']);
        $this->assertCount(2, $rows);

        $summary = app(ReportService::class)->salesSummary($fixture['store']->id, null, null, false);
        $this->assertSame(1, $summary['sales_count']);
        $this->assertSame(2500, $summary['revenue']);
        $this->assertSame(0, $summary['outstanding_amount']);
        $this->assertSame([], $summary['by_product']);

        $full = app(ReportService::class)->salesSummary($fixture['store']->id, null, null, true);
        $this->assertSame(1, $full['sales_count']);
        $this->assertArrayHasKey('by_product', $full);
        $this->assertNotEmpty($full['by_day']);
    }

    public function test_pos_overview_matches_completed_sales(): void
    {
        $fixture = $this->createTenantFixture('perfov', 'perfov@test.local');
        app(TenantContext::class)->bind($fixture['tenant']);

        $sale = Sale::create([
            'tenant_id' => $fixture['tenant']->id,
            'store_id' => $fixture['store']->id,
            'reference' => 'PERF-OV',
            'status' => SaleStatus::Completed,
            'subtotal' => 1800,
            'total' => 1800,
            'paid_amount' => 1000,
            'payment_status' => SalePaymentStatus::Partial,
            'currency' => 'FBU',
            'completed_at' => now(),
        ]);

        SaleItem::create([
            'tenant_id' => $fixture['tenant']->id,
            'sale_id' => $sale->id,
            'product_id' => $fixture['product']->id,
            'product_name' => $fixture['product']->name,
            'product_sku' => $fixture['product']->sku,
            'quantity' => 2,
            'unit_price' => 900,
            'line_total' => 1800,
        ]);

        SalePayment::create([
            'tenant_id' => $fixture['tenant']->id,
            'sale_id' => $sale->id,
            'payment_method' => 'cash',
            'amount' => 1000,
            'currency' => 'FBU',
        ]);

        $overview = app(PosOverviewService::class)->forStore($fixture['store'], now());

        $this->assertSame(1, $overview['kpis']['sales_count']);
        $this->assertSame(1800, $overview['kpis']['revenue']);
        $this->assertSame(1000, $overview['kpis']['paid_amount']);
        $this->assertSame(1800, $overview['kpis']['average_ticket']);
        $this->assertCount(24, $overview['sales_by_hour']);
        $this->assertCount(1, $overview['recent_orders']);
        $this->assertSame(2, $overview['best_selling_products'][0]['quantity']);
        $this->assertSame('cash', $overview['payment_methods'][0]['payment_method']);
        $this->assertSame(100, $overview['payment_methods'][0]['share']);
    }

    public function test_product_pages_are_capped_and_compact(): void
    {
        $fixture = $this->createTenantFixture('perfcat', 'perfcat@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $response = $this->getJson(
            '/api/v1/catalogs/'.$fixture['catalog']->id.'/products?compact=1&per_page=500',
            $headers,
        )->assertOk();

        $response->assertJsonPath('meta.per_page', 100);
        $response->assertJsonPath('meta.total', 1);
        $product = $response->json('data.0');
        $this->assertArrayNotHasKey('variants', $product);
        $this->assertArrayNotHasKey('description', $product);
        $this->assertSame($fixture['product']->sku, $product['sku']);
    }

    public function test_dashboard_home_returns_counts_without_full_lists(): void
    {
        $fixture = $this->createTenantFixture('perfhome', 'perfhome@test.local');
        $headers = $this->tenantHeaders($fixture['token'], $fixture['tenant']);

        $this->getJson(
            '/api/v1/dashboard/home?store_id='.$fixture['store']->id.'&sales=1&inventory=1',
            $headers,
        )
            ->assertOk()
            ->assertJsonPath('data.stats.products', 1)
            ->assertJsonPath('data.open_shifts', 0)
            ->assertJsonPath('data.open_alerts', 0)
            ->assertJsonPath('data.overview.kpis.sales_count', 0)
            ->assertJsonCount(0, 'data.alerts');
    }
}
