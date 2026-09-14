<?php

namespace App\Services\Desk;

use App\Models\DeskDocument;
use App\Models\Store;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class HospitalityDesk
{
    /** @return array{docs: list<array<string, mixed>>} */
    public function snapshot(Store $store): array
    {
        $this->seed($store);

        $docs = DeskDocument::query()
            ->where('store_id', $store->id)
            ->whereIn('kind', ['zone', 'table', 'server', 'room_type', 'room', 'order', 'ticket', 'reservation', 'folio'])
            ->orderBy('kind')
            ->orderBy('updated_at')
            ->get()
            ->map(fn (DeskDocument $doc) => $this->present($doc))
            ->values()
            ->all();

        return ['docs' => $docs];
    }

    /** @param  array<string, mixed>  $action
     * @return array{docs: list<array<string, mixed>>}
     */
    public function apply(Store $store, array $action): array
    {
        DB::transaction(function () use ($store, $action) {
            $this->seed($store);
            $name = (string) ($action['action'] ?? '');
            match ($name) {
                'open_order' => $this->openOrder($store, $action),
                'add_line' => $this->addLine($store, $action),
                'send_course' => $this->sendCourse($store, $action),
                'set_ticket_status' => $this->setTicketStatus($store, $action),
                'split_lines' => $this->splitLines($store, $action),
                'pay_check' => $this->payCheck($store, $action),
                'charge_room' => $this->chargeRoom($store, $action),
                'create_reservation' => $this->createReservation($store, $action),
                'check_in' => $this->checkIn($store, $action),
                'check_out' => $this->checkOut($store, $action),
                'post_folio' => $this->postFolio($store, $action),
                default => throw ValidationException::withMessages(['action' => ['Action inconnue.']]),
            };
        });

        return $this->snapshot($store);
    }

    private function seed(Store $store): void
    {
        $exists = DeskDocument::query()->where('store_id', $store->id)->where('kind', 'table')->exists();
        if ($exists) {
            return;
        }

        $this->save($store, 'zone', 'zone-salle', ['name' => 'Salle']);
        $this->save($store, 'zone', 'zone-terrasse', ['name' => 'Terrasse']);
        foreach (range(1, 4) as $i) {
            $this->save($store, 'table', "table-$i", [
                'label' => "T$i",
                'seats' => 4,
                'zone_id' => 'zone-salle',
                'status' => 'free',
            ], 'zone-salle', 'free');
        }
        foreach (range(5, 6) as $i) {
            $this->save($store, 'table', "table-$i", [
                'label' => "T$i",
                'seats' => 2,
                'zone_id' => 'zone-terrasse',
                'status' => 'free',
            ], 'zone-terrasse', 'free');
        }
        $this->save($store, 'server', 'server-1', ['name' => 'Service']);
        $this->save($store, 'room_type', 'type-standard', ['name' => 'Standard', 'rate' => 8000000]);
        $this->save($store, 'room_type', 'type-suite', ['name' => 'Suite', 'rate' => 15000000]);
        $this->save($store, 'room', 'room-201', ['number' => '201', 'type_id' => 'type-standard', 'status' => 'vacant'], null, 'vacant');
        $this->save($store, 'room', 'room-203', ['number' => '203', 'type_id' => 'type-standard', 'status' => 'vacant'], null, 'vacant');
        $this->save($store, 'room', 'room-301', ['number' => '301', 'type_id' => 'type-suite', 'status' => 'vacant'], null, 'vacant');
    }

    /** @param  array<string, mixed>  $action */
    private function openOrder(Store $store, array $action): void
    {
        $table = $this->doc($store, $this->required($action, 'table_id'));
        if (($table['status'] ?? null) === 'occupied') {
            throw ValidationException::withMessages(['table_id' => ['Table déjà occupée.']]);
        }
        $id = (string) Str::uuid();
        $checkId = (string) Str::uuid();
        $this->save($store, 'order', $id, [
            'table_id' => $table['id'],
            'table_label' => $table['label'] ?? '',
            'server_id' => $action['server_id'] ?? null,
            'status' => 'open',
            'lines' => [],
            'checks' => [['id' => $checkId, 'label' => 'Addition 1', 'status' => 'open']],
        ], (string) $table['id'], 'open');
        $table['status'] = 'occupied';
        $table['order_id'] = $id;
        $this->save($store, 'table', (string) $table['id'], $table, $table['zone_id'] ?? null, 'occupied');
    }

    /** @param  array<string, mixed>  $action */
    private function addLine(Store $store, array $action): void
    {
        $order = $this->doc($store, $this->required($action, 'order_id'));
        $check = collect($order['checks'] ?? [])->first(fn ($item) => ($item['status'] ?? null) === 'open');
        if (! is_array($check)) {
            throw ValidationException::withMessages(['order_id' => ['Aucune addition ouverte.']]);
        }
        $lines = $order['lines'] ?? [];
        $lines[] = [
            'id' => (string) Str::uuid(),
            'name' => $this->required($action, 'name'),
            'quantity' => (int) ($action['quantity'] ?? 1),
            'unit_price' => (int) ($action['unit_price'] ?? 0),
            'course' => (string) ($action['course'] ?? 'plat'),
            'product_id' => $action['product_id'] ?? null,
            'check_id' => $check['id'],
        ];
        $order['lines'] = $lines;
        if (in_array($order['status'] ?? '', ['served', 'ready'], true)) {
            $order['status'] = 'open';
        }
        $this->save($store, 'order', (string) $order['id'], $order, $order['table_id'] ?? null, $order['status'] ?? 'open');
    }

    /** @param  array<string, mixed>  $action */
    private function sendCourse(Store $store, array $action): void
    {
        $order = $this->doc($store, $this->required($action, 'order_id'));
        $course = (string) ($action['course'] ?? 'plat');
        $pending = collect($order['lines'] ?? [])->filter(fn ($line) => ($line['course'] ?? '') === $course && empty($line['ticket_id']))->values();
        if ($pending->isEmpty()) {
            throw ValidationException::withMessages(['course' => ['Rien à envoyer pour cette suite.']]);
        }
        $ticketId = (string) Str::uuid();
        $order['lines'] = collect($order['lines'] ?? [])->map(function ($line) use ($course, $ticketId) {
            if (($line['course'] ?? '') === $course && empty($line['ticket_id'])) {
                $line['ticket_id'] = $ticketId;
            }

            return $line;
        })->all();
        $this->save($store, 'ticket', $ticketId, [
            'order_id' => $order['id'],
            'table_label' => $order['table_label'] ?? '',
            'course' => $course,
            'status' => 'sent',
            'lines' => $pending->map(fn ($line) => ['name' => $line['name'], 'quantity' => $line['quantity']])->all(),
        ], (string) $order['id'], 'sent');
        $order['status'] = 'kitchen';
        $this->save($store, 'order', (string) $order['id'], $order, $order['table_id'] ?? null, 'kitchen');
    }

    /** @param  array<string, mixed>  $action */
    private function setTicketStatus(Store $store, array $action): void
    {
        $ticket = $this->doc($store, $this->required($action, 'ticket_id'));
        $status = $this->required($action, 'status');
        if (! in_array($status, ['sent', 'preparing', 'ready', 'served'], true)) {
            throw ValidationException::withMessages(['status' => ['Statut cuisine invalide.']]);
        }
        $ticket['status'] = $status;
        $this->save($store, 'ticket', (string) $ticket['id'], $ticket, $ticket['order_id'] ?? null, $status);

        $order = $this->doc($store, (string) $ticket['order_id']);
        $tickets = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'ticket')
            ->where('parent_code', $order['id'])
            ->get()
            ->map(fn (DeskDocument $doc) => $this->present($doc));
        $order['status'] = $tickets->every(fn ($item) => ($item['status'] ?? '') === 'served')
            ? 'served'
            : ($tickets->contains(fn ($item) => ($item['status'] ?? '') === 'ready')
                ? 'ready'
                : ($tickets->contains(fn ($item) => ($item['status'] ?? '') === 'preparing') ? 'preparing' : 'kitchen'));
        $this->save($store, 'order', (string) $order['id'], $order, $order['table_id'] ?? null, $order['status']);
    }

    /** @param  array<string, mixed>  $action */
    private function splitLines(Store $store, array $action): void
    {
        $order = $this->doc($store, $this->required($action, 'order_id'));
        $ids = collect($action['line_ids'] ?? [])->map(fn ($id) => (string) $id)->filter()->all();
        if ($ids === []) {
            throw ValidationException::withMessages(['line_ids' => ['Choisissez des lignes à séparer.']]);
        }
        $checks = $order['checks'] ?? [];
        $checkId = (string) Str::uuid();
        $checks[] = ['id' => $checkId, 'label' => 'Addition '.(count($checks) + 1), 'status' => 'open'];
        $moved = 0;
        $order['lines'] = collect($order['lines'] ?? [])->map(function ($line) use ($ids, $checkId, &$moved) {
            if (in_array((string) ($line['id'] ?? ''), $ids, true)) {
                $line['check_id'] = $checkId;
                $moved++;
            }

            return $line;
        })->all();
        if ($moved === 0) {
            throw ValidationException::withMessages(['line_ids' => ['Lignes introuvables.']]);
        }
        $order['checks'] = $checks;
        $this->save($store, 'order', (string) $order['id'], $order, $order['table_id'] ?? null, $order['status'] ?? 'open');
    }

    /** @param  array<string, mixed>  $action */
    private function payCheck(Store $store, array $action): void
    {
        $order = $this->doc($store, $this->required($action, 'order_id'));
        $checkId = $this->required($action, 'check_id');
        $checks = $order['checks'] ?? [];
        $found = false;
        foreach ($checks as &$check) {
            if (($check['id'] ?? '') !== $checkId) {
                continue;
            }
            if (($check['status'] ?? '') !== 'open') {
                throw ValidationException::withMessages(['check_id' => ['Addition déjà fermée.']]);
            }
            $lines = collect($order['lines'] ?? [])->where('check_id', $checkId);
            if ($lines->isEmpty()) {
                throw ValidationException::withMessages(['check_id' => ['Addition vide.']]);
            }
            $check['status'] = 'paid';
            $check['reference'] = 'CHK-'.strtoupper(Str::random(6));
            $found = true;
        }
        unset($check);
        if (! $found) {
            throw ValidationException::withMessages(['check_id' => ['Addition introuvable.']]);
        }
        $order['checks'] = $checks;
        $this->closeOrderIfDone($store, $order);
    }

    /** @param  array<string, mixed>  $action */
    private function chargeRoom(Store $store, array $action): void
    {
        $order = $this->doc($store, $this->required($action, 'order_id'));
        $room = $this->doc($store, $this->required($action, 'room_id'));
        if (($room['status'] ?? '') !== 'occupied') {
            throw ValidationException::withMessages(['room_id' => ['Chambre non occupée.']]);
        }
        $checkId = $this->required($action, 'check_id');
        $lines = collect($order['lines'] ?? [])->where('check_id', $checkId);
        if ($lines->isEmpty()) {
            throw ValidationException::withMessages(['check_id' => ['Addition vide.']]);
        }
        $folio = $this->openFolio($store, $room);
        $folioLines = $folio['lines'] ?? [];
        foreach ($lines as $line) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'restaurant',
                'description' => 'Table '.($order['table_label'] ?? '').' · '.($line['name'] ?? ''),
                'amount' => ((int) ($line['unit_price'] ?? 0)) * ((int) ($line['quantity'] ?? 0)),
                'created_at' => now()->toIso8601String(),
            ];
        }
        $folio['lines'] = $folioLines;
        $this->save($store, 'folio', (string) $folio['id'], $folio, (string) $room['id'], 'open');
        $order['checks'] = collect($order['checks'] ?? [])->map(function ($check) use ($checkId, $room) {
            if (($check['id'] ?? '') === $checkId) {
                $check['status'] = 'folio';
                $check['room_id'] = $room['id'];
                $check['room_number'] = $room['number'] ?? '';
            }

            return $check;
        })->all();
        $this->closeOrderIfDone($store, $order);
    }

    /** @param  array<string, mixed>  $action */
    private function createReservation(Store $store, array $action): void
    {
        $room = $this->doc($store, $this->required($action, 'room_id'));
        if (($room['status'] ?? '') === 'occupied') {
            throw ValidationException::withMessages(['room_id' => ['Chambre occupée.']]);
        }
        $id = (string) Str::uuid();
        $this->save($store, 'reservation', $id, [
            'room_id' => $room['id'],
            'room_number' => $room['number'] ?? '',
            'guest_name' => $this->required($action, 'guest_name'),
            'arrive_on' => $action['arrive_on'] ?? now()->toIso8601String(),
            'depart_on' => $action['depart_on'] ?? null,
            'status' => 'reserved',
        ], (string) $room['id'], 'reserved');
        $room['status'] = 'reserved';
        $this->save($store, 'room', (string) $room['id'], $room, null, 'reserved');
    }

    /** @param  array<string, mixed>  $action */
    private function checkIn(Store $store, array $action): void
    {
        $reservation = $this->doc($store, $this->required($action, 'reservation_id'));
        if (($reservation['status'] ?? '') !== 'reserved') {
            throw ValidationException::withMessages(['reservation_id' => ['Réservation non ouvrable.']]);
        }
        $room = $this->doc($store, (string) $reservation['room_id']);
        $folioId = (string) Str::uuid();
        $this->save($store, 'folio', $folioId, [
            'room_id' => $room['id'],
            'room_number' => $room['number'] ?? '',
            'reservation_id' => $reservation['id'],
            'guest_name' => $reservation['guest_name'] ?? '',
            'status' => 'open',
            'lines' => [],
        ], (string) $room['id'], 'open');
        $reservation['status'] = 'checked_in';
        $reservation['folio_id'] = $folioId;
        $this->save($store, 'reservation', (string) $reservation['id'], $reservation, (string) $room['id'], 'checked_in');
        $room['status'] = 'occupied';
        $room['guest_name'] = $reservation['guest_name'] ?? '';
        $room['folio_id'] = $folioId;
        $this->save($store, 'room', (string) $room['id'], $room, null, 'occupied');
    }

    /** @param  array<string, mixed>  $action */
    private function checkOut(Store $store, array $action): void
    {
        $reservation = $this->doc($store, $this->required($action, 'reservation_id'));
        if (($reservation['status'] ?? '') !== 'checked_in') {
            throw ValidationException::withMessages(['reservation_id' => ['Aucun séjour en cours.']]);
        }
        $folio = $this->doc($store, (string) $reservation['folio_id']);
        $folio['status'] = 'closed';
        $folio['reference'] = 'HTL-'.strtoupper(Str::random(6));
        $this->save($store, 'folio', (string) $folio['id'], $folio, $folio['room_id'] ?? null, 'closed');
        $reservation['status'] = 'checked_out';
        $this->save($store, 'reservation', (string) $reservation['id'], $reservation, $reservation['room_id'] ?? null, 'checked_out');
        $room = $this->doc($store, (string) $reservation['room_id']);
        $room['status'] = 'vacant';
        unset($room['guest_name'], $room['folio_id']);
        $this->save($store, 'room', (string) $room['id'], $room, null, 'vacant');
    }

    /** @param  array<string, mixed>  $action */
    private function postFolio(Store $store, array $action): void
    {
        $room = $this->doc($store, $this->required($action, 'room_id'));
        if (($room['status'] ?? '') !== 'occupied') {
            throw ValidationException::withMessages(['room_id' => ['Chambre non occupée.']]);
        }
        $kind = (string) ($action['kind'] ?? 'minibar');
        if (! in_array($kind, ['minibar', 'room_service'], true)) {
            throw ValidationException::withMessages(['kind' => ['Type de consommation invalide.']]);
        }
        $folio = $this->openFolio($store, $room);
        $lines = $folio['lines'] ?? [];
        $lines[] = [
            'id' => (string) Str::uuid(),
            'kind' => $kind,
            'description' => trim((string) ($action['description'] ?? '')) !== ''
                ? trim((string) $action['description'])
                : ($kind === 'minibar' ? 'Minibar' : 'Room service'),
            'amount' => (int) ($action['amount'] ?? 0),
            'created_at' => now()->toIso8601String(),
        ];
        $folio['lines'] = $lines;
        $this->save($store, 'folio', (string) $folio['id'], $folio, (string) $room['id'], 'open');
    }

    /** @param  array<string, mixed>  $order */
    private function closeOrderIfDone(Store $store, array $order): void
    {
        $done = collect($order['checks'] ?? [])->every(fn ($check) => ($check['status'] ?? '') !== 'open');
        if ($done) {
            $order['status'] = 'paid';
        }
        $this->save($store, 'order', (string) $order['id'], $order, $order['table_id'] ?? null, $order['status'] ?? 'open');
        if (! $done) {
            return;
        }
        $table = $this->doc($store, (string) $order['table_id']);
        $table['status'] = 'free';
        unset($table['order_id']);
        $this->save($store, 'table', (string) $table['id'], $table, $table['zone_id'] ?? null, 'free');
    }

    /** @param  array<string, mixed>  $room
     * @return array<string, mixed>
     */
    private function openFolio(Store $store, array $room): array
    {
        $folioId = $room['folio_id'] ?? null;
        if (! is_string($folioId) || $folioId === '') {
            throw ValidationException::withMessages(['room_id' => ['Aucun folio ouvert pour cette chambre.']]);
        }

        return $this->doc($store, $folioId);
    }

    /** @param  array<string, mixed>  $action */
    private function required(array $action, string $key): string
    {
        $value = trim((string) ($action[$key] ?? ''));
        if ($value === '') {
            throw ValidationException::withMessages([$key => ['Champ requis.']]);
        }

        return $value;
    }

    /** @return array<string, mixed> */
    private function doc(Store $store, string $code): array
    {
        $row = DeskDocument::query()->where('store_id', $store->id)->where('code', $code)->first();
        if ($row === null) {
            throw ValidationException::withMessages(['id' => ['Document introuvable.']]);
        }

        return $this->present($row);
    }

    /** @param  array<string, mixed>  $payload */
    private function save(Store $store, string $kind, string $code, array $payload, ?string $parent = null, ?string $status = null): void
    {
        $payload['id'] = $code;
        if ($status !== null) {
            $payload['status'] = $status;
        }
        DeskDocument::query()->updateOrCreate(
            ['store_id' => $store->id, 'code' => $code],
            [
                'tenant_id' => $store->tenant_id,
                'kind' => $kind,
                'parent_code' => $parent,
                'status' => $status ?? ($payload['status'] ?? null),
                'payload' => $payload,
            ],
        );
    }

    /** @return array<string, mixed> */
    private function present(DeskDocument $doc): array
    {
        return array_merge($doc->payload ?? [], [
            'id' => $doc->code,
            'kind' => $doc->kind,
            'status' => $doc->status ?? ($doc->payload['status'] ?? null),
        ]);
    }
}
