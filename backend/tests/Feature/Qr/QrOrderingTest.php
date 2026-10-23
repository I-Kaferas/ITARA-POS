<?php

namespace Tests\Feature\Qr;

use App\Enums\SaleStatus;
use App\Models\DeskDocument;
use App\Models\PosTable;
use App\Models\QrOrder;
use App\Models\QrTableSession;
use App\Models\Sale;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class QrOrderingTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    private array $fixture;

    protected function setUp(): void
    {
        parent::setUp();
        $this->fixture = $this->createTenantFixture('qrorder', 'qrorder@test.local');
        $this->fixture['product']->importToStore($this->fixture['store']);
    }

    public function test_guest_order_is_priced_on_the_server_and_approved_into_a_sale(): void
    {
        $table = $this->makeTable('Table 5');
        $token = $this->issue($table)['order_url'];
        $secret = substr($token, strrpos($token, '=') + 1);

        $this->getJson('/api/v1/public/qr/not-a-real-token')->assertNotFound();

        $menu = $this->getJson("/api/v1/public/qr/{$secret}")
            ->assertOk()
            ->json('data');
        $this->assertSame('Table 5', $menu['table']['name']);
        $this->assertTrue($menu['ordering_open']);

        $payload = [
            'idempotency_key' => 'guest-round-1',
            'items' => [[
                'product_id' => $this->fixture['product']->id,
                'quantity' => 2,
                'note' => 'sans sucre',
                'unit_price' => 1,
            ]],
        ];
        $this->postJson("/api/v1/public/qr/{$secret}/orders", $payload)->assertStatus(422);

        unset($payload['items'][0]['unit_price']);
        $created = $this->postJson("/api/v1/public/qr/{$secret}/orders", $payload)
            ->assertCreated()
            ->json('data');
        $this->assertSame('sent', $created['guest_status']);
        $this->assertSame(2000, $created['total']);
        $this->assertSame('sans sucre', $created['items'][0]['note']);

        $again = $this->postJson("/api/v1/public/qr/{$secret}/orders", $payload)
            ->assertCreated()
            ->json('data');
        $this->assertSame($created['id'], $again['id']);
        $this->assertSame(1, QrOrder::query()->count());

        $approved = $this->postJson("/api/v1/qr-orders/{$created['id']}/approve", [], $this->headers())
            ->assertOk()
            ->json('data');
        $this->assertSame('approved', $approved['guest_status']);

        $sale = Sale::query()->findOrFail($approved['sale_id']);
        $this->assertSame(SaleStatus::Pending, $sale->status);
        $this->assertSame('qr_client', $sale->source);
        $this->assertSame($table->id, $sale->table_id);
        $this->assertSame(2000, $sale->total);
        $this->assertNotNull(
            DeskDocument::query()->where('store_id', $this->fixture['store']->id)->where('kind', 'ticket')->first()
        );

        $tracked = $this->getJson("/api/v1/public/qr/{$secret}/orders/{$created['id']}")
            ->assertOk()
            ->json('data');
        $this->assertContains($tracked['guest_status'], ['approved', 'preparing', 'ready', 'served']);
    }

    public function test_reject_cancel_closed_table_and_second_round_share_the_sale(): void
    {
        $table = $this->makeTable('Table 8');
        $secret = $this->secret($table);
        $product = $this->fixture['product']->id;

        $first = $this->postJson("/api/v1/public/qr/{$secret}/orders", [
            'idempotency_key' => 'round-a',
            'items' => [['product_id' => $product, 'quantity' => 1]],
        ])->assertCreated()->json('data');

        $this->postJson("/api/v1/public/qr/{$secret}/orders/{$first['id']}/cancel")
            ->assertOk()
            ->assertJsonPath('data.guest_status', 'cancelled');

        $this->patchJson("/api/v1/pos-tables/{$table->id}/status", [
            'status' => 'cleaning',
        ], $this->headers())->assertOk();

        $this->postJson("/api/v1/public/qr/{$secret}/orders", [
            'idempotency_key' => 'round-blocked',
            'items' => [['product_id' => $product, 'quantity' => 1]],
        ])->assertStatus(422);

        $this->patchJson("/api/v1/pos-tables/{$table->id}/status", [
            'status' => 'available',
        ], $this->headers())->assertOk();

        $second = $this->postJson("/api/v1/public/qr/{$secret}/orders", [
            'idempotency_key' => 'round-b',
            'items' => [['product_id' => $product, 'quantity' => 1, 'note' => 'peu salé']],
        ])->assertCreated()->json('data');

        $this->postJson("/api/v1/qr-orders/{$second['id']}/reject", [
            'reason' => 'Rupture',
        ], $this->headers())->assertOk()->assertJsonPath('data.rejection_reason', 'Rupture');

        $third = $this->postJson("/api/v1/public/qr/{$secret}/orders", [
            'idempotency_key' => 'round-c',
            'items' => [['product_id' => $product, 'quantity' => 1]],
        ])->assertCreated()->json('data');
        $fourth = $this->postJson("/api/v1/public/qr/{$secret}/orders", [
            'idempotency_key' => 'round-d',
            'items' => [['product_id' => $product, 'quantity' => 2]],
        ])->assertCreated()->json('data');

        $this->postJson("/api/v1/stores/{$this->fixture['store']->id}/qr-orders/approve-all", [], $this->headers())
            ->assertOk()
            ->assertJsonPath('data.approved', 2);

        $saleId = QrOrder::query()->findOrFail($third['id'])->sale_id;
        $this->assertSame($saleId, QrOrder::query()->findOrFail($fourth['id'])->sale_id);
        $this->assertSame(3000, Sale::query()->findOrFail($saleId)->total);
        $this->assertSame(1, QrTableSession::query()->where('status', 'open')->count());
    }

    /** @return array<string, string> */
    private function headers(): array
    {
        return $this->tenantHeaders($this->fixture['token'], $this->fixture['tenant']);
    }

    private function makeTable(string $name): PosTable
    {
        $store = $this->fixture['store'];
        $payload = $this->postJson("/api/v1/stores/{$store->id}/pos/tables", [
            'name' => $name,
            'capacity' => 4,
        ], $this->headers())->assertCreated()->json('data');

        return PosTable::query()->findOrFail($payload['id']);
    }

    /** @return array<string, mixed> */
    private function issue(PosTable $table): array
    {
        return $this->postJson(
            "/api/v1/stores/{$table->store_id}/pos-tables/{$table->id}/qr-token",
            [],
            $this->headers(),
        )->assertCreated()->json('data');
    }

    private function secret(PosTable $table): string
    {
        $url = $this->issue($table)['order_url'];

        return substr($url, strrpos($url, '=') + 1);
    }
}
