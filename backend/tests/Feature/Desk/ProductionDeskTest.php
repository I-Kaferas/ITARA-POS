<?php

namespace Tests\Feature\Desk;

use App\Models\Product;
use App\Models\StockBalance;
use App\Models\Warehouse;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class ProductionDeskTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_recipe_lifecycle_produces_and_reverses_stock(): void
    {
        $fixture = $this->createTenantFixture('prod-life', 'prod-life@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );
        $warehouse = $fixture['warehouse'];

        $flour = $this->product($fixture, 'FLOUR', 'Farine', 200);
        $sauce = $this->product($fixture, 'SAUCE', 'Sauce', 100);
        $pizza = $this->product($fixture, 'PIZZA', 'Pizza maison', 0);
        $this->stock($headers, $warehouse, $flour, 10);
        $this->stock($headers, $warehouse, $sauce, 5);

        $empty = $this->getJson('/api/v1/production', $headers)->assertOk();
        $this->assertSame([], $empty->json('data.recipes'));
        $this->assertFalse(Product::query()->where('sku', 'PIZZA')->where('id', '!=', $pizza->id)->exists());

        $saved = $this->postJson('/api/v1/production/actions', [
            'action' => 'save_recipe',
            'product_id' => $pizza->id,
            'yield_quantity' => 2,
            'lines' => [
                ['product_id' => $flour->id, 'quantity' => 2],
                ['product_id' => $sauce->id, 'quantity' => 1],
            ],
        ], $headers)->assertOk();
        $recipe = collect($saved->json('data.recipes'))->firstWhere('id', $pizza->id);
        $this->assertSame(2, $recipe['yield_quantity']);
        $this->assertSame(5, $recipe['max_batches']);
        $this->assertSame(500, $recipe['batch_cost']);
        $this->assertSame(250, $recipe['unit_cost']);

        $produced = $this->postJson('/api/v1/production/actions', [
            'action' => 'produce',
            'recipe_id' => $pizza->id,
            'batches' => 3,
        ], $headers)->assertOk();
        $this->assertSame(4, $this->onHand($warehouse, $flour));
        $this->assertSame(2, $this->onHand($warehouse, $sauce));
        $this->assertSame(6, $this->onHand($warehouse, $pizza));
        $run = $produced->json('data.runs.0');
        $this->assertSame(6, $run['finished_quantity']);
        $this->assertSame(1500, $run['total_cost']);
        $this->assertSame('done', $run['status']);
        $this->assertSame(1, $produced->json('data.stats.runs_today'));
        $this->assertSame(6, $produced->json('data.stats.units_today'));

        $this->postJson('/api/v1/production/actions', [
            'action' => 'produce',
            'recipe_id' => $pizza->id,
            'batches' => 3,
        ], $headers)->assertStatus(422)->assertJsonValidationErrors('batches');
        $this->assertSame(4, $this->onHand($warehouse, $flour));
        $this->assertSame(6, $this->onHand($warehouse, $pizza));

        $reversed = $this->postJson('/api/v1/production/actions', [
            'action' => 'reverse_run',
            'run_id' => $run['id'],
        ], $headers)->assertOk();
        $this->assertSame('reversed', $reversed->json('data.runs.0.status'));
        $this->assertSame(10, $this->onHand($warehouse, $flour));
        $this->assertSame(5, $this->onHand($warehouse, $sauce));
        $this->assertSame(0, $this->onHand($warehouse, $pizza));
        $this->assertSame(0, $reversed->json('data.stats.units_today'));

        $this->postJson('/api/v1/production/actions', [
            'action' => 'reverse_run',
            'run_id' => $run['id'],
        ], $headers)->assertStatus(422);

        $this->postJson('/api/v1/production/actions', [
            'action' => 'produce',
            'recipe_id' => $pizza->id,
            'batches' => 1,
        ], $headers)->assertOk();
        $this->postJson("/api/v1/stores/{$fixture['store']->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [['product_id' => $pizza->id, 'quantity' => 1]],
            'payments' => [['method' => 'cash', 'amount' => 1000]],
        ], $headers)->assertCreated();
        $this->assertSame(1, $this->onHand($warehouse, $pizza));
        $this->assertSame(8, $this->onHand($warehouse, $flour));

        $this->postJson('/api/v1/production/actions', [
            'action' => 'delete_recipe',
            'recipe_id' => $pizza->id,
        ], $headers)->assertOk()->assertJsonPath('data.recipes', []);
    }

    public function test_recipe_rejects_bundles_self_reference_and_duplicates(): void
    {
        $fixture = $this->createTenantFixture('prod-rules', 'prod-rules@test.local');
        $headers = array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );
        $flour = $this->product($fixture, 'FLOUR2', 'Farine', 200);
        $bread = $this->product($fixture, 'BREAD', 'Pain', 0);
        $kit = $this->product($fixture, 'KIT', 'Kit', 0, 'bundle');

        $this->postJson('/api/v1/production/actions', [
            'action' => 'save_recipe',
            'product_id' => $kit->id,
            'lines' => [['product_id' => $flour->id, 'quantity' => 1]],
        ], $headers)->assertStatus(422)->assertJsonValidationErrors('product_id');

        $this->postJson('/api/v1/production/actions', [
            'action' => 'save_recipe',
            'product_id' => $bread->id,
            'lines' => [['product_id' => $bread->id, 'quantity' => 1]],
        ], $headers)->assertStatus(422)->assertJsonValidationErrors('lines');

        $this->postJson('/api/v1/production/actions', [
            'action' => 'save_recipe',
            'product_id' => $bread->id,
            'lines' => [
                ['product_id' => $flour->id, 'quantity' => 1],
                ['product_id' => $flour->id, 'quantity' => 2],
            ],
        ], $headers)->assertStatus(422)->assertJsonValidationErrors('lines');

        $this->postJson('/api/v1/production/actions', [
            'action' => 'produce',
            'recipe_id' => $bread->id,
            'batches' => 1,
        ], $headers)->assertStatus(422)->assertJsonValidationErrors('recipe_id');
    }

    /** @param  array<string, mixed>  $fixture */
    private function product(array $fixture, string $sku, string $name, int $cost, string $type = 'simple'): Product
    {
        $product = Product::create([
            'tenant_id' => $fixture['tenant']->id,
            'catalog_id' => $fixture['catalog']->id,
            'product_type' => $type,
            'sku' => $sku,
            'name' => $name,
            'base_price' => 1000,
            'cost_price' => $cost,
            'is_active' => true,
        ]);
        $product->importToStore($fixture['store']);

        return $product;
    }

    /** @param  array<string, string>  $headers */
    private function stock(array $headers, Warehouse $warehouse, Product $product, int $quantity): void
    {
        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => $quantity,
            'unit_cost' => $product->cost_price,
        ], $headers)->assertCreated();
    }

    private function onHand(Warehouse $warehouse, Product $product): int
    {
        return (int) StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->sum('quantity_on_hand');
    }
}
