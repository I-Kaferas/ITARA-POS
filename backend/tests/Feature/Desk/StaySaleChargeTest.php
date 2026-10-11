<?php

namespace Tests\Feature\Desk;

use App\Models\DeskDocument;
use App\Models\Sale;
use App\Models\StockBalance;
use App\Services\Desk\HospitalityDesk;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\Support\InteractsWithTenants;
use Tests\TestCase;

class StaySaleChargeTest extends TestCase
{
    use InteractsWithTenants;
    use RefreshDatabase;

    public function test_pos_sale_is_charged_once_to_the_stay_and_checkout_keeps_it(): void
    {
        $fixture = $this->createTenantFixture('stay-charge', 'stay-charge@test.local');
        $headers = $this->headers($fixture);
        $store = $fixture['store'];
        $product = $fixture['product'];
        $warehouse = $fixture['warehouse'];
        $product->importToStore($store);

        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 10,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();
        $checkedIn = $this->postJson('/api/v1/hospitality/actions', $this->walkIn('Jean Dupont', 'CD-1'), $headers)->assertOk();
        $stay = collect($checkedIn->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Jean Dupont');
        $this->assertNotEmpty($stay['folio_id']);

        $sale = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                [
                    'method' => 'room',
                    'amount' => 1000,
                    'metadata' => ['reservation_id' => $stay['id']],
                ],
            ],
        ], $headers)->assertCreated();

        $saleId = $sale->json('data.sale.id');
        $this->assertSame('paid', $sale->json('data.sale.payment_status'));

        $folio = $this->folio($headers, $stay['id']);
        $posted = collect($folio['lines'])->where('sale_id', $saleId);
        $this->assertNotEmpty($posted);
        $this->assertTrue($posted->every(fn ($line) => ($line['reservation_id'] ?? null) === $stay['id']));
        $this->assertSame(1000, (int) $posted->sum('amount'));
        $this->assertSame('pos', $posted->first()['kind']);

        $model = Sale::query()->findOrFail($saleId);
        try {
            app(HospitalityDesk::class)->postSaleCharge($store, $model, $stay['id'], 1000);
            $this->fail('A sale must not be charged twice.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('sale_id', $exception->errors());
        }

        $checkedOut = $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'check_out',
            'reservation_id' => $stay['id'],
        ], $headers)->assertOk();
        $closed = collect($checkedOut->json('data.docs'))->first(fn ($doc) => ($doc['id'] ?? null) === $stay['folio_id']);
        $this->assertSame('closed', $closed['status']);
        $this->assertTrue(collect($closed['lines'])->contains(fn ($line) => ($line['sale_id'] ?? null) === $saleId));

        $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                [
                    'method' => 'room',
                    'amount' => 1000,
                    'metadata' => ['reservation_id' => $stay['id']],
                ],
            ],
        ], $headers)->assertStatus(422);

        $balance = StockBalance::query()
            ->where('warehouse_id', $warehouse->id)
            ->where('product_id', $product->id)
            ->first();
        $this->assertSame(9, $balance?->quantity_on_hand);
    }

    public function test_cash_sale_is_not_charged_again_and_other_tenant_stay_is_rejected(): void
    {
        $fixture = $this->createTenantFixture('stay-cash', 'stay-cash@test.local');
        $headers = $this->headers($fixture);
        $store = $fixture['store'];
        $product = $fixture['product'];
        $warehouse = $fixture['warehouse'];
        $product->importToStore($store);
        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 5,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $cash = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                ['method' => 'cash', 'amount' => 1000],
            ],
        ], $headers)->assertCreated();
        $this->assertSame('paid', $cash->json('data.sale.payment_status'));

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();
        $checkedIn = $this->postJson('/api/v1/hospitality/actions', $this->walkIn('Marie Kabila', 'CD-9'), $headers)->assertOk();
        $stay = collect($checkedIn->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Marie Kabila');

        $model = Sale::query()->findOrFail($cash->json('data.sale.id'));
        try {
            app(HospitalityDesk::class)->postSaleCharge($store, $model, $stay['id'], 1000);
            $this->fail('A settled cash sale must not be posted to a stay.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('sale_id', $exception->errors());
        }

        $other = $this->createTenantFixture('stay-other', 'stay-other@test.local');
        $otherHeaders = $this->headers($other);
        $this->getJson('/api/v1/hospitality', $otherHeaders)->assertOk();
        $foreign = $this->postJson('/api/v1/hospitality/actions', $this->walkIn('Autre Client', 'CD-8'), $otherHeaders)->assertOk();
        $foreignStay = collect($foreign->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Autre Client');

        $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
            'payments' => [
                [
                    'method' => 'room',
                    'amount' => 1000,
                    'metadata' => ['reservation_id' => $foreignStay['id']],
                ],
            ],
        ], $headers)->assertStatus(422);

        $this->assertSame(0, DeskDocument::query()
            ->where('store_id', $other['store']->id)
            ->where('kind', 'folio')
            ->get()
            ->filter(fn (DeskDocument $doc) => collect($doc->payload['lines'] ?? [])->contains(fn ($line) => ($line['kind'] ?? null) === 'pos'))
            ->count());
    }

    public function test_room_change_keeps_the_charge_on_the_original_stay(): void
    {
        $fixture = $this->createTenantFixture('stay-move', 'stay-move@test.local');
        $headers = $this->headers($fixture);
        $store = $fixture['store'];
        $product = $fixture['product'];
        $warehouse = $fixture['warehouse'];
        $product->importToStore($store);
        $this->postJson("/api/v1/warehouses/{$warehouse->id}/movements", [
            'product_id' => $product->id,
            'movement_type' => 'INITIAL_STOCK',
            'quantity' => 5,
            'unit_cost' => 500,
        ], $headers)->assertCreated();

        $this->getJson('/api/v1/hospitality', $headers)->assertOk();
        DeskDocument::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'code' => 'room-202',
            'kind' => 'room',
            'status' => 'vacant',
            'payload' => ['id' => 'room-202', 'number' => '202', 'status' => 'vacant'],
        ]);
        $checkedIn = $this->postJson('/api/v1/hospitality/actions', $this->walkIn('Paul Nday', 'CD-3'), $headers)->assertOk();
        $stay = collect($checkedIn->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Paul Nday');

        $sale = $this->postJson("/api/v1/stores/{$store->id}/sales", [
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
            'payments' => [
                [
                    'method' => 'room',
                    'amount' => 2000,
                    'metadata' => ['reservation_id' => $stay['id']],
                ],
            ],
        ], $headers)->assertCreated();

        $this->postJson('/api/v1/hospitality/actions', [
            'action' => 'change_stay_room',
            'reservation_id' => $stay['id'],
            'room_id' => 'room-202',
        ], $headers)->assertOk();

        $next = $this->postJson('/api/v1/hospitality/actions', $this->walkIn('Nouveau Client', 'CD-4', 'room-201'), $headers)->assertOk();
        $newStay = collect($next->json('data.docs'))
            ->first(fn ($doc) => ($doc['kind'] ?? null) === 'reservation' && ($doc['guest_name'] ?? '') === 'Nouveau Client');
        $newFolio = collect($next->json('data.docs'))->first(fn ($doc) => ($doc['id'] ?? null) === $newStay['folio_id']);
        $this->assertFalse(collect($newFolio['lines'] ?? [])->contains(
            fn ($line) => ($line['sale_id'] ?? null) === $sale->json('data.sale.id'),
        ));

        $original = $this->folio($headers, $stay['id']);
        $this->assertSame('room-202', $original['room_id'] ?? collect($this->docs($headers))->first(fn ($doc) => ($doc['id'] ?? null) === $stay['id'])['room_id']);
        $this->assertTrue(collect($original['lines'])->contains(
            fn ($line) => ($line['sale_id'] ?? null) === $sale->json('data.sale.id') && ($line['reservation_id'] ?? null) === $stay['id'],
        ));
    }

    /** @param  array<string, mixed>  $fixture */
    private function headers(array $fixture): array
    {
        return array_merge(
            $this->tenantHeaders($fixture['token'], $fixture['tenant']),
            ['X-Store-ID' => $fixture['store']->id],
        );
    }

    /** @return array<string, string> */
    private function walkIn(string $name, string $document, string $roomId = 'room-201'): array
    {
        return [
            'action' => 'walk_in_check_in',
            'guest_name' => $name,
            'nationality' => 'Congolaise',
            'id_document_type' => 'national_id',
            'id_document_number' => $document,
            'purpose' => 'Affaires',
            'room_id' => $roomId,
            'arrive_on' => now()->toDateString(),
            'depart_on' => now()->addDay()->toDateString(),
        ];
    }

    /** @param  array<string, string>  $headers
     * @return array<string, mixed>
     */
    private function folio(array $headers, string $reservationId): array
    {
        $reservation = collect($this->docs($headers))->first(fn ($doc) => ($doc['id'] ?? null) === $reservationId);

        return collect($this->docs($headers))->first(fn ($doc) => ($doc['id'] ?? null) === ($reservation['folio_id'] ?? ''));
    }

    /** @param  array<string, string>  $headers
     * @return list<array<string, mixed>>
     */
    private function docs(array $headers): array
    {
        return $this->getJson('/api/v1/hospitality', $headers)->assertOk()->json('data.docs');
    }
}
