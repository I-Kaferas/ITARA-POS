<?php

namespace Tests\Feature\Catalog;

use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class ProductAccompanimentTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('acc1', 'acc1@test.local');
    }

    public function test_product_can_be_marked_as_accompaniment(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);

        $this->patchJson('/api/v1/products/'.$this->fixture['product']->id, [
            'accompaniment_enabled' => true,
        ], $headers)->assertOk()
            ->assertJsonPath('data.accompaniment_enabled', true);

        $this->getJson('/api/v1/product-accompaniments/candidates', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.id', $this->fixture['product']->id);
    }

    public function test_host_product_can_be_linked_to_free_accompaniments(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $host = $this->fixture['product'];
        $fries = $this->createSide('Frites');
        $salad = $this->createSide('Salade');

        $this->postJson('/api/v1/product-accompaniments', [
            'product_id' => $host->id,
            'accompaniment_product_ids' => [$fries->id, $salad->id],
        ], $headers)->assertCreated()
            ->assertJsonPath('data.product.id', $host->id)
            ->assertJsonPath('data.accompaniments.0.id', $fries->id)
            ->assertJsonPath('data.accompaniments.1.id', $salad->id);

        $this->getJson('/api/v1/product-accompaniments', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.product.id', $host->id)
            ->assertJsonCount(2, 'data.0.accompaniments');

        $this->putJson('/api/v1/products/'.$host->id.'/accompaniment', [
            'accompaniment_product_ids' => [$salad->id],
        ], $headers)->assertOk()
            ->assertJsonCount(1, 'data.accompaniments')
            ->assertJsonPath('data.accompaniments.0.id', $salad->id);
    }

    public function test_product_not_marked_as_accompaniment_cannot_be_linked(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $plain = Product::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'catalog_id' => $this->fixture['catalog']->id,
            'sku' => 'PLAIN-001',
            'name' => 'Plain',
            'base_price' => 500,
            'is_active' => true,
            'accompaniment_enabled' => false,
        ]);

        $this->postJson('/api/v1/product-accompaniments', [
            'product_id' => $this->fixture['product']->id,
            'accompaniment_product_ids' => [$plain->id],
        ], $headers)->assertUnprocessable();
    }

    public function test_disabling_accompaniment_flag_removes_existing_links(): void
    {
        $headers = $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
        $host = $this->fixture['product'];
        $fries = $this->createSide('Frites');

        $this->postJson('/api/v1/product-accompaniments', [
            'product_id' => $host->id,
            'accompaniment_product_ids' => [$fries->id],
        ], $headers)->assertCreated();

        $this->patchJson('/api/v1/products/'.$fries->id, [
            'accompaniment_enabled' => false,
        ], $headers)->assertOk();

        $this->getJson('/api/v1/product-accompaniments', $headers)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    private function createSide(string $name): Product
    {
        return Product::query()->create([
            'tenant_id' => $this->fixture['tenant']->id,
            'catalog_id' => $this->fixture['catalog']->id,
            'sku' => strtoupper(str_replace(' ', '-', $name)).'-ACC',
            'name' => $name,
            'base_price' => 300,
            'is_active' => true,
            'accompaniment_enabled' => true,
        ]);
    }
}
