<?php

namespace App\Services\Desk;

use App\Models\DeskDocument;
use App\Models\Store;
use App\Models\Tenant;
use App\Support\TenantBranding;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class HospitalityDesk
{
    /** @return array{docs: list<array<string, mixed>>} */
    public function snapshot(Store $store): array
    {
        $this->seed($store);
        $this->ensureAmenities($store);
        $this->ensureHotelSettings($store);

        $docs = DeskDocument::query()
            ->where('store_id', $store->id)
            ->whereIn('kind', ['zone', 'table', 'server', 'amenity', 'building', 'wing', 'floor', 'room_type', 'room', 'order', 'ticket', 'reservation', 'folio', 'hotel_settings', 'concierge_request', 'housekeeping_task'])
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
            $this->ensureAmenities($store);
            $this->ensureHotelSettings($store);
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
                'upsert_reservation' => $this->upsertReservation($store, $action),
                'delete_reservation' => $this->deleteReservation($store, $action),
                'check_in' => $this->checkIn($store, $action),
                'walk_in_check_in' => $this->walkInCheckIn($store, $action),
                'create_stay_sign_link' => $this->createStaySignLink($store, $action),
                'submit_stay_signature' => $this->submitStaySignature($store, $action),
                'check_out' => $this->checkOut($store, $action),
                'post_folio' => $this->postFolio($store, $action),
                'change_stay_room' => $this->changeStayRoom($store, $action),
                'collect_stay_payment' => $this->collectStayPayment($store, $action),
                'upsert_room_type' => $this->upsertRoomType($store, $action),
                'delete_room_type' => $this->deleteRoomType($store, $action),
                'upsert_amenity' => $this->upsertAmenity($store, $action),
                'delete_amenity' => $this->deleteAmenity($store, $action),
                'upsert_building' => $this->upsertBuilding($store, $action),
                'delete_building' => $this->deleteBuilding($store, $action),
                'upsert_wing' => $this->upsertWing($store, $action),
                'delete_wing' => $this->deleteWing($store, $action),
                'upsert_floor' => $this->upsertFloor($store, $action),
                'delete_floor' => $this->deleteFloor($store, $action),
                'upsert_room' => $this->upsertRoom($store, $action),
                'delete_room' => $this->deleteRoom($store, $action),
                'set_room_housekeeping' => $this->setRoomHousekeeping($store, $action),
                'upsert_housekeeping_task' => $this->upsertHousekeepingTask($store, $action),
                'delete_housekeeping_task' => $this->deleteHousekeepingTask($store, $action),
                'set_housekeeping_task_status' => $this->setHousekeepingTaskStatus($store, $action),
                'upsert_hotel_settings' => $this->upsertHotelSettings($store, $action),
                'upsert_concierge_request' => $this->upsertConciergeRequest($store, $action),
                'delete_concierge_request' => $this->deleteConciergeRequest($store, $action),
                'set_concierge_status' => $this->setConciergeStatus($store, $action),
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
        $this->save($store, 'room_type', 'type-standard', [
            'name' => 'Standard',
            'code' => 'STANDARD',
            'space_kind' => 'guest_room',
            'rate' => 8000000,
            'base_price_cents' => 8000000,
            'currency' => 'USD',
            'max_adults' => 2,
            'bed_type' => 'Queen',
            'bed_count' => 1,
            'is_active' => true,
            'amenity_ids' => [],
            'highlights' => [],
            'photo_urls' => [],
        ]);
        $this->save($store, 'room_type', 'type-suite', [
            'name' => 'Suite',
            'code' => 'SUITE',
            'space_kind' => 'guest_room',
            'rate' => 15000000,
            'base_price_cents' => 15000000,
            'currency' => 'USD',
            'max_adults' => 2,
            'bed_type' => 'King',
            'bed_count' => 1,
            'is_active' => true,
            'amenity_ids' => [],
            'highlights' => [],
            'photo_urls' => [],
        ]);
        $this->save($store, 'room', 'room-201', ['number' => '201', 'type_id' => 'type-standard', 'status' => 'vacant'], null, 'vacant');
        $this->save($store, 'room', 'room-203', ['number' => '203', 'type_id' => 'type-standard', 'status' => 'vacant'], null, 'vacant');
        $this->save($store, 'room', 'room-301', ['number' => '301', 'type_id' => 'type-suite', 'status' => 'vacant'], null, 'vacant');
        $this->ensureAmenities($store);
    }

    private function ensureAmenities(Store $store): void
    {
        $defaults = [
            ['wifi', 'Wi‑Fi haut débit', 'connectivity'],
            ['tv', 'Télévision écran plat', 'entertainment'],
            ['ac', 'Climatisation', 'climate'],
            ['minibar', 'Minibar', 'comfort'],
            ['safe', 'Coffre-fort', 'security'],
            ['balcony', 'Balcon', 'comfort'],
            ['bathtub', 'Baignoire', 'bathroom'],
            ['shower', 'Douche', 'bathroom'],
            ['desk', 'Bureau de travail', 'comfort'],
            ['kettle', 'Bouilloire', 'comfort'],
            ['hairdryer', 'Sèche-cheveux', 'bathroom'],
            ['projector', 'Projecteur', 'conference'],
            ['sound', 'Sono / micro', 'conference'],
            ['stage', 'Scène', 'conference'],
            ['catering', 'Espace traiteur', 'conference'],
        ];

        foreach ($defaults as $index => [$code, $name, $category]) {
            $id = "amenity-$code";
            $row = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('code', $id)
                ->first();
            $payload = [
                'name' => $name,
                'code' => strtoupper($code),
                'category' => $category,
                'replacement_value_cents' => 0,
                'display_order' => $index,
                'icon_key' => $code,
                'is_active' => true,
            ];
            if ($row !== null) {
                $existing = $row->payload ?? [];
                $missing = ! array_key_exists('category', $existing)
                    || ! array_key_exists('replacement_value_cents', $existing)
                    || ! array_key_exists('display_order', $existing)
                    || ! array_key_exists('icon_key', $existing);
                if (! $missing) {
                    continue;
                }
                $payload = array_merge($payload, $existing, [
                    'name' => $existing['name'] ?? $name,
                    'code' => $existing['code'] ?? strtoupper($code),
                    'category' => $existing['category'] ?? $category,
                    'replacement_value_cents' => $existing['replacement_value_cents'] ?? 0,
                    'display_order' => $existing['display_order'] ?? $index,
                    'icon_key' => $existing['icon_key'] ?? $code,
                    'is_active' => array_key_exists('is_active', $existing) ? (bool) $existing['is_active'] : true,
                ]);
            }
            $this->save($store, 'amenity', $id, $payload, null, ($payload['is_active'] ?? true) ? 'active' : 'inactive');
        }
    }

    /** @param  array<string, mixed>  $action */
    private function upsertAmenity(Store $store, array $action): void
    {
        $name = trim((string) ($action['name'] ?? ''));
        if ($name === '') {
            throw ValidationException::withMessages(['name' => ['Le nom est requis.']]);
        }

        $category = strtolower(trim((string) ($action['category'] ?? 'other')));
        if (! in_array($category, $this->amenityCategories(), true)) {
            throw ValidationException::withMessages(['category' => ['Catégorie invalide.']]);
        }

        $id = trim((string) ($action['id'] ?? ''));
        if ($id === '') {
            $id = 'amenity-'.Str::slug($name);
            if ($id === 'amenity-') {
                $id = 'amenity-'.Str::lower(Str::random(6));
            }
            $base = $id;
            $i = 2;
            while (DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->exists()) {
                $id = $base.'-'.$i;
                $i++;
            }
        }

        $code = trim((string) ($action['code'] ?? ''));
        if ($code === '') {
            $code = Str::upper(Str::slug($name, '_'));
            $code = $code !== '' ? $code : 'AMENITY';
        } else {
            $code = Str::upper(Str::slug($code, '_'));
            $code = $code !== '' ? $code : 'AMENITY';
        }

        $baseCode = $code;
        $n = 2;
        while ($this->amenityCodeTaken($store, $code, $id)) {
            $code = $baseCode.'_'.$n;
            $n++;
        }

        $iconKey = strtolower(trim((string) ($action['icon_key'] ?? '')));
        if ($iconKey !== '' && ! preg_match('/^[a-z0-9][a-z0-9_-]{0,39}$/', $iconKey)) {
            throw ValidationException::withMessages(['icon_key' => ['Clé d\'icône invalide.']]);
        }

        $this->save($store, 'amenity', $id, [
            'name' => $name,
            'code' => $code,
            'category' => $category,
            'replacement_value_cents' => max(0, (int) ($action['replacement_value_cents'] ?? 0)),
            'display_order' => (int) ($action['display_order'] ?? 0),
            'icon_key' => $iconKey,
            'is_active' => (bool) ($action['is_active'] ?? true),
        ], null, (bool) ($action['is_active'] ?? true) ? 'active' : 'inactive');
    }

    /** @param  array<string, mixed>  $action */
    private function deleteAmenity(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $inUse = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room_type')
            ->get()
            ->contains(function (DeskDocument $doc) use ($id) {
                $ids = $doc->payload['amenity_ids'] ?? [];

                return is_array($ids) && in_array($id, $ids, true);
            });
        if ($inUse) {
            throw ValidationException::withMessages(['id' => ['Cet équipement est utilisé par au moins un type de chambre.']]);
        }
        DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->where('kind', 'amenity')->delete();
    }

    /** @return list<string> */
    private function amenityCategories(): array
    {
        return ['other', 'connectivity', 'entertainment', 'climate', 'bathroom', 'comfort', 'security', 'conference'];
    }

    private function amenityCodeTaken(Store $store, string $code, string $exceptId): bool
    {
        return DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'amenity')
            ->where('code', '!=', $exceptId)
            ->get()
            ->contains(fn (DeskDocument $doc) => strtoupper((string) ($doc->payload['code'] ?? '')) === $code);
    }

    /** @param  array<string, mixed>  $action */
    private function upsertBuilding(Store $store, array $action): void
    {
        $name = trim((string) ($action['name'] ?? ''));
        if ($name === '') {
            throw ValidationException::withMessages(['name' => ['Le nom est requis.']]);
        }

        $id = trim((string) ($action['id'] ?? ''));
        if ($id === '') {
            $id = 'building-'.Str::slug($name);
            if ($id === 'building-') {
                $id = 'building-'.Str::lower(Str::random(6));
            }
            $base = $id;
            $i = 2;
            while (DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->exists()) {
                $id = $base.'-'.$i;
                $i++;
            }
        }

        $this->save($store, 'building', $id, [
            'name' => $name,
            'display_order' => (int) ($action['display_order'] ?? 0),
            'is_active' => (bool) ($action['is_active'] ?? true),
        ], null, (bool) ($action['is_active'] ?? true) ? 'active' : 'inactive');
    }

    /** @param  array<string, mixed>  $action */
    private function deleteBuilding(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $inUse = DeskDocument::query()
            ->where('store_id', $store->id)
            ->whereIn('kind', ['wing', 'floor', 'room'])
            ->get()
            ->contains(fn (DeskDocument $doc) => ($doc->payload['building_id'] ?? null) === $id);
        if ($inUse) {
            throw ValidationException::withMessages(['id' => ['Ce bâtiment est utilisé par au moins une aile, un étage ou une chambre.']]);
        }
        DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->where('kind', 'building')->delete();
    }

    /** @param  array<string, mixed>  $action */
    private function upsertRoomType(Store $store, array $action): void
    {
        $name = trim((string) ($action['name'] ?? ''));
        if ($name === '') {
            throw ValidationException::withMessages(['name' => ['Le nom est requis.']]);
        }

        $spaceKind = (string) ($action['space_kind'] ?? 'guest_room');
        if (! in_array($spaceKind, ['guest_room', 'conference', 'reception'], true)) {
            throw ValidationException::withMessages(['space_kind' => ['Type d\'espace invalide.']]);
        }

        $id = trim((string) ($action['id'] ?? ''));
        if ($id === '') {
            $id = 'type-'.Str::slug($name);
            if ($id === 'type-') {
                $id = 'type-'.Str::lower(Str::random(6));
            }
            $base = $id;
            $i = 2;
            while (DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->exists()) {
                $id = $base.'-'.$i;
                $i++;
            }
        }

        $code = trim((string) ($action['code'] ?? ''));
        if ($code === '') {
            $code = Str::upper(Str::slug($name, '_'));
            $code = $code !== '' ? $code : 'TYPE';
        }

        $amenityIds = collect($action['amenity_ids'] ?? [])
            ->filter(fn ($value) => is_string($value) && $value !== '')
            ->values()
            ->all();
        $highlights = collect($action['highlights'] ?? [])
            ->map(fn ($value) => trim((string) $value))
            ->filter(fn ($value) => $value !== '')
            ->values()
            ->all();
        $photoUrls = collect($action['photo_urls'] ?? [])
            ->map(fn ($value) => trim((string) $value))
            ->filter(fn ($value) => $value !== '')
            ->values()
            ->all();

        $basePrice = (int) ($action['base_price_cents'] ?? $action['rate'] ?? 0);

        $this->save($store, 'room_type', $id, [
            'name' => $name,
            'code' => $code,
            'space_kind' => $spaceKind,
            'rate' => $basePrice,
            'base_price_cents' => $basePrice,
            'currency' => strtoupper((string) ($action['currency'] ?? 'USD')),
            'max_adults' => max(1, (int) ($action['max_adults'] ?? 2)),
            'bed_type' => trim((string) ($action['bed_type'] ?? 'Queen')) ?: 'Queen',
            'bed_count' => max(1, (int) ($action['bed_count'] ?? 1)),
            'surface_m2' => isset($action['surface_m2']) && $action['surface_m2'] !== '' && $action['surface_m2'] !== null
                ? (float) $action['surface_m2']
                : null,
            'is_active' => (bool) ($action['is_active'] ?? true),
            'description' => trim((string) ($action['description'] ?? '')),
            'marketing_hook' => trim((string) ($action['marketing_hook'] ?? '')),
            'highlights' => $highlights,
            'amenity_ids' => $amenityIds,
            'photo_urls' => $photoUrls,
        ], null, (bool) ($action['is_active'] ?? true) ? 'active' : 'inactive');
    }

    /** @param  array<string, mixed>  $action */
    private function deleteRoomType(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $inUse = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room')
            ->get()
            ->contains(fn (DeskDocument $doc) => ($doc->payload['type_id'] ?? null) === $id);
        if ($inUse) {
            throw ValidationException::withMessages(['id' => ['Ce type est utilisé par au moins une chambre.']]);
        }
        DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->where('kind', 'room_type')->delete();
    }

    /** @param  array<string, mixed>  $action */
    private function upsertWing(Store $store, array $action): void
    {
        $name = trim((string) ($action['name'] ?? ''));
        if ($name === '') {
            throw ValidationException::withMessages(['name' => ['Le nom est requis.']]);
        }

        $buildingId = $this->required($action, 'building_id');
        $building = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'building')
            ->where('code', $buildingId)
            ->first();
        if ($building === null) {
            throw ValidationException::withMessages(['building_id' => ['Bâtiment introuvable.']]);
        }

        $id = trim((string) ($action['id'] ?? ''));
        if ($id === '') {
            $id = 'wing-'.Str::slug($name);
            if ($id === 'wing-') {
                $id = 'wing-'.Str::lower(Str::random(6));
            }
            $base = $id;
            $i = 2;
            while (DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->exists()) {
                $id = $base.'-'.$i;
                $i++;
            }
        }

        $this->save($store, 'wing', $id, [
            'name' => $name,
            'building_id' => $buildingId,
            'building_name' => (string) ($building->payload['name'] ?? $buildingId),
            'display_order' => (int) ($action['display_order'] ?? 0),
            'is_active' => (bool) ($action['is_active'] ?? true),
        ], $buildingId, (bool) ($action['is_active'] ?? true) ? 'active' : 'inactive');
    }

    /** @param  array<string, mixed>  $action */
    private function deleteWing(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $inUse = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'floor')
            ->get()
            ->contains(fn (DeskDocument $doc) => ($doc->payload['wing_id'] ?? null) === $id || $doc->parent_code === $id);
        if ($inUse) {
            throw ValidationException::withMessages(['id' => ['Cette aile / zone a au moins un étage.']]);
        }
        DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->where('kind', 'wing')->delete();
    }

    /** @param  array<string, mixed>  $action */
    private function upsertFloor(Store $store, array $action): void
    {
        if (! array_key_exists('floor_number', $action) || $action['floor_number'] === '' || $action['floor_number'] === null) {
            throw ValidationException::withMessages(['floor_number' => ['Le numéro d\'étage est requis.']]);
        }
        if (! is_numeric($action['floor_number']) || (int) $action['floor_number'] != $action['floor_number']) {
            throw ValidationException::withMessages(['floor_number' => ['Le numéro d\'étage est invalide.']]);
        }
        $floorNumber = (int) $action['floor_number'];

        $buildingId = $this->required($action, 'building_id');
        $building = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'building')
            ->where('code', $buildingId)
            ->first();
        if ($building === null) {
            throw ValidationException::withMessages(['building_id' => ['Bâtiment introuvable.']]);
        }

        $wingId = trim((string) ($action['wing_id'] ?? ''));
        $wingName = '';
        if ($wingId !== '') {
            $wing = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('kind', 'wing')
                ->where('code', $wingId)
                ->first();
            if ($wing === null) {
                throw ValidationException::withMessages(['wing_id' => ['Aile / zone introuvable.']]);
            }
            if (($wing->payload['building_id'] ?? null) !== $buildingId) {
                throw ValidationException::withMessages(['wing_id' => ['Cette aile / zone n\'appartient pas à ce bâtiment.']]);
            }
            $wingName = (string) ($wing->payload['name'] ?? $wingId);
        }

        $id = trim((string) ($action['id'] ?? ''));
        if ($id === '') {
            $id = 'floor-'.Str::slug($buildingId).'-'.($wingId !== '' ? Str::slug($wingId) : 'all').'-'.$floorNumber;
            $base = $id;
            $i = 2;
            while (DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->exists()) {
                $id = $base.'-'.$i;
                $i++;
            }
        }

        $duplicate = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'floor')
            ->where('code', '!=', $id)
            ->get()
            ->contains(function (DeskDocument $doc) use ($buildingId, $wingId, $floorNumber) {
                $payload = $doc->payload ?? [];

                return ($payload['building_id'] ?? '') === $buildingId
                    && (string) ($payload['wing_id'] ?? '') === $wingId
                    && (int) ($payload['floor_number'] ?? 0) === $floorNumber
                    && array_key_exists('floor_number', $payload);
            });
        if ($duplicate) {
            throw ValidationException::withMessages(['floor_number' => ['Ce numéro d\'étage existe déjà pour ce bâtiment / cette aile.']]);
        }

        $this->save($store, 'floor', $id, [
            'name' => trim((string) ($action['name'] ?? '')),
            'floor_number' => $floorNumber,
            'building_id' => $buildingId,
            'building_name' => (string) ($building->payload['name'] ?? $buildingId),
            'wing_id' => $wingId !== '' ? $wingId : null,
            'wing_name' => $wingName,
            'display_order' => (int) ($action['display_order'] ?? 0),
            'is_active' => (bool) ($action['is_active'] ?? true),
        ], $wingId !== '' ? $wingId : $buildingId, (bool) ($action['is_active'] ?? true) ? 'active' : 'inactive');
    }

    /** @param  array<string, mixed>  $action */
    private function deleteFloor(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $inUse = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room')
            ->get()
            ->contains(fn (DeskDocument $doc) => ($doc->payload['floor_id'] ?? null) === $id);
        if ($inUse) {
            throw ValidationException::withMessages(['id' => ['Cet étage est utilisé par au moins une chambre.']]);
        }
        DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->where('kind', 'floor')->delete();
    }

    /** @param  array<string, mixed>  $action */
    private function upsertRoom(Store $store, array $action): void
    {
        $mode = (string) ($action['mode'] ?? 'single');
        if (! in_array($mode, ['single', 'range'], true)) {
            throw ValidationException::withMessages(['mode' => ['Mode invalide.']]);
        }

        $buildingId = $this->required($action, 'building_id');
        $building = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'building')
            ->where('code', $buildingId)
            ->first();
        if ($building === null) {
            throw ValidationException::withMessages(['building_id' => ['Bâtiment introuvable.']]);
        }

        $wingId = trim((string) ($action['wing_id'] ?? ''));
        $wingName = '';
        if ($wingId !== '') {
            $wing = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('kind', 'wing')
                ->where('code', $wingId)
                ->first();
            if ($wing === null) {
                throw ValidationException::withMessages(['wing_id' => ['Aile / zone introuvable.']]);
            }
            if (($wing->payload['building_id'] ?? null) !== $buildingId) {
                throw ValidationException::withMessages(['wing_id' => ['Cette aile / zone n\'appartient pas à ce bâtiment.']]);
            }
            $wingName = (string) ($wing->payload['name'] ?? $wingId);
        }

        $floorId = $this->required($action, 'floor_id');
        $floor = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'floor')
            ->where('code', $floorId)
            ->first();
        if ($floor === null) {
            throw ValidationException::withMessages(['floor_id' => ['Étage introuvable.']]);
        }
        if (($floor->payload['building_id'] ?? null) !== $buildingId) {
            throw ValidationException::withMessages(['floor_id' => ['Cet étage n\'appartient pas à ce bâtiment.']]);
        }
        $floorWing = (string) ($floor->payload['wing_id'] ?? '');
        if ($wingId !== '' && $floorWing !== '' && $floorWing !== $wingId) {
            throw ValidationException::withMessages(['floor_id' => ['Cet étage n\'appartient pas à cette aile / zone.']]);
        }
        if ($wingId === '' && $floorWing !== '') {
            // floor tied to a wing but form selected whole building — still allow if user picks that floor
            $wingId = $floorWing;
            $wingName = (string) ($floor->payload['wing_name'] ?? $floorWing);
        }

        $typeId = $this->required($action, 'type_id');
        $type = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room_type')
            ->where('code', $typeId)
            ->first();
        if ($type === null) {
            throw ValidationException::withMessages(['type_id' => ['Type de chambre introuvable.']]);
        }

        $spaceKind = (string) ($action['space_kind'] ?? ($type->payload['space_kind'] ?? 'guest_room'));
        if (! in_array($spaceKind, ['guest_room', 'conference', 'reception'], true)) {
            throw ValidationException::withMessages(['space_kind' => ['Type d\'espace invalide.']]);
        }

        $housekeeping = (string) ($action['housekeeping_status'] ?? 'clean');
        if (! in_array($housekeeping, $this->housekeepingStatuses(), true)) {
            throw ValidationException::withMessages(['housekeeping_status' => ['État housekeeping invalide.']]);
        }

        $photoUrls = collect($action['photo_urls'] ?? [])
            ->map(fn ($value) => trim((string) $value))
            ->filter(fn ($value) => $value !== '')
            ->values()
            ->all();

        $priceOverride = array_key_exists('price_override_cents', $action) && $action['price_override_cents'] !== null && $action['price_override_cents'] !== ''
            ? max(0, (int) $action['price_override_cents'])
            : null;
        $maxAdultsOverride = array_key_exists('max_adults_override', $action) && $action['max_adults_override'] !== null && $action['max_adults_override'] !== ''
            ? max(1, (int) $action['max_adults_override'])
            : null;
        $maxChildrenOverride = array_key_exists('max_children_override', $action) && $action['max_children_override'] !== null && $action['max_children_override'] !== ''
            ? max(0, (int) $action['max_children_override'])
            : null;

        $displayName = trim((string) ($action['display_name'] ?? ''));
        $notes = trim((string) ($action['notes'] ?? ''));
        $isActive = (bool) ($action['is_active'] ?? true);

        $numbers = [];
        if ($mode === 'range' && empty($action['id'])) {
            $from = trim((string) ($action['number_from'] ?? ''));
            $to = trim((string) ($action['number_to'] ?? ''));
            if ($from === '' || $to === '' || ! ctype_digit($from) || ! ctype_digit($to)) {
                throw ValidationException::withMessages(['number_from' => ['La plage doit contenir des numéros entiers.']]);
            }
            $start = (int) $from;
            $end = (int) $to;
            if ($end < $start) {
                throw ValidationException::withMessages(['number_to' => ['Le numéro de fin doit être ≥ au début.']]);
            }
            if (($end - $start) > 200) {
                throw ValidationException::withMessages(['number_to' => ['Plage trop large (max 200 chambres).']]);
            }
            foreach (range($start, $end) as $n) {
                $numbers[] = (string) $n;
            }
        } else {
            $number = trim((string) ($action['number'] ?? ''));
            if ($number === '') {
                throw ValidationException::withMessages(['number' => ['Le numéro de chambre est requis.']]);
            }
            $numbers[] = $number;
        }

        foreach ($numbers as $number) {
            $id = trim((string) ($action['id'] ?? ''));
            if ($id === '') {
                $id = 'room-'.Str::slug($buildingId).'-'.Str::slug($number);
                if ($id === 'room-'.Str::slug($buildingId).'-') {
                    $id = 'room-'.Str::lower(Str::random(8));
                }
                $base = $id;
                $i = 2;
                while (DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->exists()) {
                    $id = $base.'-'.$i;
                    $i++;
                }
            }

            $taken = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('kind', 'room')
                ->where('code', '!=', $id)
                ->get()
                ->contains(function (DeskDocument $doc) use ($buildingId, $number) {
                    return ($doc->payload['building_id'] ?? null) === $buildingId
                        && (string) ($doc->payload['number'] ?? '') === $number;
                });
            if ($taken) {
                throw ValidationException::withMessages(['number' => ["Le numéro {$number} existe déjà dans ce bâtiment."]]);
            }

            $existing = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('code', $id)
                ->where('kind', 'room')
                ->first();
            $status = $existing?->status ?? ($existing?->payload['status'] ?? 'vacant');
            if (! in_array($status, ['vacant', 'occupied', 'reserved'], true)) {
                $status = 'vacant';
            }

            $this->save($store, 'room', $id, [
                'number' => $number,
                'name' => $displayName !== '' ? $displayName : $number,
                'display_name' => $displayName,
                'type_id' => $typeId,
                'type_name' => (string) ($type->payload['name'] ?? $typeId),
                'space_kind' => $spaceKind,
                'building_id' => $buildingId,
                'building_name' => (string) ($building->payload['name'] ?? $buildingId),
                'wing_id' => $wingId !== '' ? $wingId : null,
                'wing_name' => $wingName,
                'floor_id' => $floorId,
                'floor_name' => (string) ($floor->payload['name'] ?? ('Étage '.($floor->payload['floor_number'] ?? ''))),
                'floor_number' => (int) ($floor->payload['floor_number'] ?? 0),
                'housekeeping_status' => $housekeeping,
                'is_active' => $isActive,
                'price_override_cents' => $priceOverride,
                'max_adults_override' => $maxAdultsOverride,
                'max_children_override' => $maxChildrenOverride,
                'photo_urls' => $photoUrls,
                'notes' => $notes,
                'hk_priority' => (string) ($existing?->payload['hk_priority'] ?? 'low'),
                'hk_assignee_id' => $existing?->payload['hk_assignee_id'] ?? null,
                'hk_assignee_name' => $existing?->payload['hk_assignee_name'] ?? null,
                'status' => $status,
            ], $floorId, $status);
        }
    }

    /** @param  array<string, mixed>  $action */
    private function deleteRoom(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $room = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room')
            ->where('code', $id)
            ->first();
        if ($room === null) {
            throw ValidationException::withMessages(['id' => ['Chambre introuvable.']]);
        }
        $status = $room->status ?? ($room->payload['status'] ?? 'vacant');
        if ($status === 'occupied') {
            throw ValidationException::withMessages(['id' => ['Impossible de supprimer une chambre occupée.']]);
        }
        DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->where('kind', 'room')->delete();
    }

    /** @return list<string> */
    private function housekeepingStatuses(): array
    {
        return ['clean', 'dirty', 'cleaning', 'inspected', 'maintenance', 'out_of_service'];
    }

    /** @param  array<string, mixed>  $action */
    private function setRoomHousekeeping(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $status = (string) ($action['housekeeping_status'] ?? '');
        if (! in_array($status, $this->housekeepingStatuses(), true)) {
            throw ValidationException::withMessages(['housekeeping_status' => ['État housekeeping invalide.']]);
        }

        $room = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room')
            ->where('code', $id)
            ->first();
        if ($room === null) {
            throw ValidationException::withMessages(['id' => ['Chambre introuvable.']]);
        }

        $payload = $room->payload ?? [];
        $payload['housekeeping_status'] = $status;

        if (array_key_exists('hk_priority', $action) && $action['hk_priority'] !== null && $action['hk_priority'] !== '') {
            $priority = strtolower(trim((string) $action['hk_priority']));
            if (! in_array($priority, $this->hkPriorities(), true)) {
                throw ValidationException::withMessages(['hk_priority' => ['Priorité housekeeping invalide.']]);
            }
            $payload['hk_priority'] = $priority;
        } elseif (! isset($payload['hk_priority']) || $payload['hk_priority'] === '') {
            $payload['hk_priority'] = 'low';
        }

        if (array_key_exists('hk_assignee_id', $action) || array_key_exists('hk_assignee_name', $action)) {
            $payload['hk_assignee_id'] = trim((string) ($action['hk_assignee_id'] ?? '')) ?: null;
            $payload['hk_assignee_name'] = trim((string) ($action['hk_assignee_name'] ?? '')) ?: null;
        }

        if (array_key_exists('notes', $action)) {
            $payload['notes'] = trim((string) $action['notes']);
        }

        $roomStatus = $room->status ?? ($payload['status'] ?? 'vacant');
        $roomStatus = is_string($roomStatus) ? $roomStatus : 'vacant';
        $this->save($store, 'room', $id, $payload, $room->parent_code, $roomStatus);
        $this->syncHousekeepingTaskForRoom($store, array_merge($payload, [
            'id' => $id,
            'kind' => 'room',
            'status' => $roomStatus,
        ]));
    }

    /** @return list<string> */
    private function hkPriorities(): array
    {
        return ['low', 'normal', 'high', 'urgent'];
    }

    /** @return list<string> */
    private function housekeepingTaskTypes(): array
    {
        return ['cleaning', 'inspection', 'turndown', 'linen', 'maintenance'];
    }

    /** @return list<string> */
    private function housekeepingTaskStatuses(): array
    {
        return ['pending', 'assigned', 'in_progress', 'done', 'cancelled'];
    }

    private function nextHousekeepingTaskNo(Store $store): string
    {
        $count = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'housekeeping_task')
            ->count() + 1;

        return 'HK-'.str_pad((string) $count, 3, '0', STR_PAD_LEFT);
    }

    /**
     * @param  array<string, mixed>  $room
     */
    private function syncHousekeepingTaskForRoom(Store $store, array $room): void
    {
        $roomId = (string) ($room['id'] ?? '');
        if ($roomId === '') {
            return;
        }

        $hk = (string) ($room['housekeeping_status'] ?? 'clean');
        $open = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'housekeeping_task')
            ->where('parent_code', $roomId)
            ->whereIn('status', ['pending', 'assigned', 'in_progress'])
            ->get();

        if (in_array($hk, ['dirty', 'cleaning'], true)) {
            $assigneeId = $room['hk_assignee_id'] ?? null;
            $assigneeName = $room['hk_assignee_name'] ?? null;
            $hasAssignee = (is_string($assigneeId) && $assigneeId !== '') || (is_string($assigneeName) && $assigneeName !== '');
            $status = $hk === 'cleaning' ? 'in_progress' : ($hasAssignee ? 'assigned' : 'pending');
            if ($open->isEmpty()) {
                $id = (string) Str::uuid();
                $this->save($store, 'housekeeping_task', $id, [
                    'task_no' => $this->nextHousekeepingTaskNo($store),
                    'title' => 'Nettoyage chambre '.($room['number'] ?? $room['name'] ?? ''),
                    'room_id' => $roomId,
                    'room_number' => (string) ($room['number'] ?? ''),
                    'type' => 'cleaning',
                    'priority' => (string) ($room['hk_priority'] ?? 'low'),
                    'assignee_id' => $assigneeId,
                    'assignee_name' => $assigneeName,
                    'notes' => null,
                    'due_on' => now()->toDateString(),
                    'status' => $status,
                ], $roomId, $status);

                return;
            }

            foreach ($open as $doc) {
                $payload = $doc->payload ?? [];
                $payload['status'] = $status;
                $payload['room_number'] = (string) ($room['number'] ?? ($payload['room_number'] ?? ''));
                if (array_key_exists('hk_assignee_id', $room) || array_key_exists('hk_assignee_name', $room)) {
                    $payload['assignee_id'] = $room['hk_assignee_id'] ?? null;
                    $payload['assignee_name'] = $room['hk_assignee_name'] ?? null;
                }
                if (! empty($room['hk_priority'])) {
                    $payload['priority'] = $room['hk_priority'];
                }
                $this->save($store, 'housekeeping_task', $doc->code, $payload, $doc->parent_code, $status);
            }

            return;
        }

        if (! in_array($hk, ['clean', 'inspected'], true)) {
            return;
        }

        foreach ($open as $doc) {
            $type = (string) (($doc->payload['type'] ?? 'cleaning'));
            if (! in_array($type, ['cleaning', 'inspection', 'turndown', 'linen'], true)) {
                continue;
            }
            $payload = $doc->payload ?? [];
            $payload['status'] = 'done';
            $payload['completed_at'] = now()->toIso8601String();
            $this->save($store, 'housekeeping_task', $doc->code, $payload, $doc->parent_code, 'done');
        }
    }

    /** @param  array<string, mixed>  $action */
    private function upsertHousekeepingTask(Store $store, array $action): void
    {
        $roomId = trim((string) ($action['room_id'] ?? ''));
        if ($roomId === '') {
            throw ValidationException::withMessages(['room_id' => ['La chambre est requise.']]);
        }

        $room = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room')
            ->where('code', $roomId)
            ->first();
        if ($room === null) {
            throw ValidationException::withMessages(['room_id' => ['Chambre introuvable.']]);
        }

        $type = strtolower(trim((string) ($action['type'] ?? 'cleaning')));
        if (! in_array($type, $this->housekeepingTaskTypes(), true)) {
            throw ValidationException::withMessages(['type' => ['Type de tâche invalide.']]);
        }

        $priority = strtolower(trim((string) ($action['priority'] ?? ($room->payload['hk_priority'] ?? 'low'))));
        if (! in_array($priority, $this->hkPriorities(), true)) {
            throw ValidationException::withMessages(['priority' => ['Priorité invalide.']]);
        }

        $status = strtolower(trim((string) ($action['status'] ?? 'pending')));
        if (! in_array($status, $this->housekeepingTaskStatuses(), true)) {
            throw ValidationException::withMessages(['status' => ['Statut de tâche invalide.']]);
        }

        $dueOn = trim((string) ($action['due_on'] ?? ''));
        $assigneeId = trim((string) ($action['assignee_id'] ?? '')) ?: null;
        $assigneeName = trim((string) ($action['assignee_name'] ?? '')) ?: null;
        $hasAssignee = $assigneeId !== null || $assigneeName !== null;
        if ($status === 'pending' && $hasAssignee) {
            $status = 'assigned';
        }
        if ($status === 'assigned' && ! $hasAssignee) {
            $status = 'pending';
        }

        $id = trim((string) ($action['id'] ?? ''));
        $isNew = $id === '';
        $existing = null;
        if (! $isNew) {
            $existing = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('kind', 'housekeeping_task')
                ->where('code', $id)
                ->first();
            if ($existing === null) {
                throw ValidationException::withMessages(['id' => ['Tâche introuvable.']]);
            }
        } else {
            $id = (string) Str::uuid();
        }

        $taskNo = (string) ($existing?->payload['task_no'] ?? '');
        if ($taskNo === '') {
            $taskNo = $this->nextHousekeepingTaskNo($store);
        }

        $notes = trim((string) ($action['notes'] ?? '')) ?: null;
        $roomNumber = (string) ($room->payload['number'] ?? $room->payload['name'] ?? $roomId);
        $title = trim((string) ($action['title'] ?? ($existing?->payload['title'] ?? '')));
        if ($title === '') {
            $title = match ($type) {
                'inspection' => 'Inspection chambre '.$roomNumber,
                'turndown' => 'Turndown chambre '.$roomNumber,
                'linen' => 'Linge chambre '.$roomNumber,
                'maintenance' => 'Maintenance chambre '.$roomNumber,
                default => 'Nettoyage chambre '.$roomNumber,
            };
        }

        $payload = [
            'task_no' => $taskNo,
            'title' => $title,
            'room_id' => $roomId,
            'room_number' => $roomNumber,
            'type' => $type,
            'priority' => $priority,
            'assignee_id' => $assigneeId,
            'assignee_name' => $assigneeName,
            'notes' => $notes,
            'due_on' => $dueOn !== '' ? $dueOn : ($existing?->payload['due_on'] ?? now()->toDateString()),
            'completed_at' => $existing?->payload['completed_at'] ?? null,
            'status' => $status,
        ];
        if ($status === 'done' && empty($payload['completed_at'])) {
            $payload['completed_at'] = now()->toIso8601String();
        }
        if ($status !== 'done') {
            $payload['completed_at'] = null;
        }

        $this->save($store, 'housekeeping_task', $id, $payload, $roomId, $status);

        $roomPayload = $room->payload ?? [];
        $roomStatus = is_string($room->status ?? null) ? $room->status : (string) ($roomPayload['status'] ?? 'vacant');
        $hk = (string) ($roomPayload['housekeeping_status'] ?? 'clean');
        $nextHk = $hk;
        if (in_array($type, ['cleaning', 'linen', 'turndown'], true)) {
            if (in_array($status, ['pending', 'assigned'], true) && in_array($hk, ['clean', 'inspected', ''], true)) {
                $nextHk = 'dirty';
            }
            if ($status === 'in_progress') {
                $nextHk = 'cleaning';
            }
            if ($status === 'done' && in_array($hk, ['dirty', 'cleaning'], true)) {
                $nextHk = 'clean';
            }
        }
        if ($type === 'inspection' && $status === 'done' && in_array($hk, ['clean', 'cleaning', 'dirty'], true)) {
            $nextHk = 'inspected';
        }
        if ($type === 'maintenance' && in_array($status, ['pending', 'assigned', 'in_progress'], true) && $hk !== 'out_of_service') {
            $nextHk = 'maintenance';
        }

        $roomPayload['hk_priority'] = $priority;
        $roomPayload['hk_assignee_id'] = $assigneeId;
        $roomPayload['hk_assignee_name'] = $assigneeName;
        if ($nextHk !== $hk) {
            $roomPayload['housekeeping_status'] = $nextHk;
        }
        $this->save($store, 'room', $roomId, $roomPayload, $room->parent_code, $roomStatus);
    }

    /** @param  array<string, mixed>  $action */
    private function deleteHousekeepingTask(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'housekeeping_task')
            ->where('code', $id)
            ->delete();
    }

    /** @param  array<string, mixed>  $action */
    private function setHousekeepingTaskStatus(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $status = strtolower(trim((string) ($action['status'] ?? '')));
        if (! in_array($status, $this->housekeepingTaskStatuses(), true)) {
            throw ValidationException::withMessages(['status' => ['Statut de tâche invalide.']]);
        }

        $row = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'housekeeping_task')
            ->where('code', $id)
            ->first();
        if ($row === null) {
            throw ValidationException::withMessages(['id' => ['Tâche introuvable.']]);
        }

        $this->upsertHousekeepingTask($store, array_merge($row->payload ?? [], [
            'id' => $id,
            'room_id' => $row->payload['room_id'] ?? $row->parent_code,
            'status' => $status,
            'assignee_id' => $action['assignee_id'] ?? ($row->payload['assignee_id'] ?? null),
            'assignee_name' => $action['assignee_name'] ?? ($row->payload['assignee_name'] ?? null),
        ]));
    }

    /** @return list<string> */
    private function conciergeCategories(): array
    {
        return ['room_service', 'transport', 'activity', 'maintenance', 'special', 'vip'];
    }

    /** @return list<string> */
    private function conciergePriorities(): array
    {
        return ['low', 'normal', 'high', 'urgent'];
    }

    /** @return list<string> */
    private function conciergeStatuses(): array
    {
        return ['new', 'acknowledged', 'in_progress', 'done', 'cancelled'];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function appendConciergeHistory(array $payload, string $status, ?string $by = null): array
    {
        $history = $payload['status_history'] ?? [];
        if (! is_array($history)) {
            $history = [];
        }
        $history[] = [
            'status' => $status,
            'at' => now()->toIso8601String(),
            'by' => $by,
        ];
        $payload['status_history'] = $history;
        $payload['status'] = $status;
        if ($status === 'done') {
            $payload['completed_at'] = now()->toIso8601String();
        }
        if ($status === 'cancelled') {
            $payload['cancelled_at'] = now()->toIso8601String();
        }

        return $payload;
    }

    private function nextConciergeNo(Store $store): string
    {
        $count = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'concierge_request')
            ->count() + 1;

        return 'CON-'.str_pad((string) $count, 3, '0', STR_PAD_LEFT);
    }

    /** @param  array<string, mixed>  $action */
    private function upsertConciergeRequest(Store $store, array $action): void
    {
        $guestName = trim((string) ($action['guest_name'] ?? ''));
        if ($guestName === '') {
            throw ValidationException::withMessages(['guest_name' => ['Le nom du client est requis.']]);
        }

        $roomNumber = trim((string) ($action['room_number'] ?? ''));
        if ($roomNumber === '') {
            throw ValidationException::withMessages(['room_number' => ['La chambre est requise.']]);
        }

        $title = trim((string) ($action['title'] ?? ''));
        if ($title === '') {
            throw ValidationException::withMessages(['title' => ['Le titre est requis.']]);
        }

        $category = strtolower(trim((string) ($action['category'] ?? 'room_service')));
        if (! in_array($category, $this->conciergeCategories(), true)) {
            throw ValidationException::withMessages(['category' => ['Catégorie invalide.']]);
        }

        $priority = strtolower(trim((string) ($action['priority'] ?? 'normal')));
        if (! in_array($priority, $this->conciergePriorities(), true)) {
            throw ValidationException::withMessages(['priority' => ['Priorité invalide.']]);
        }

        $status = strtolower(trim((string) ($action['status'] ?? 'new')));
        if (! in_array($status, $this->conciergeStatuses(), true)) {
            throw ValidationException::withMessages(['status' => ['Statut invalide.']]);
        }

        $assigneeType = strtolower(trim((string) ($action['assignee_type'] ?? 'internal')));
        if (! in_array($assigneeType, ['internal', 'supplier'], true)) {
            throw ValidationException::withMessages(['assignee_type' => ['Type d’assignation invalide.']]);
        }

        $id = trim((string) ($action['id'] ?? ''));
        $isNew = $id === '';
        $existing = null;
        if (! $isNew) {
            $existing = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('kind', 'concierge_request')
                ->where('code', $id)
                ->first();
            if ($existing === null) {
                throw ValidationException::withMessages(['id' => ['Demande introuvable.']]);
            }
        } else {
            $id = (string) Str::uuid();
        }

        $requestNo = (string) ($existing?->payload['request_no'] ?? '');
        if ($requestNo === '') {
            $requestNo = $this->nextConciergeNo($store);
        }

        $scheduledAt = trim((string) ($action['scheduled_at'] ?? ''));
        $assigneeName = trim((string) ($action['assignee_name'] ?? ''));
        $reservationId = trim((string) ($action['reservation_id'] ?? '')) ?: null;
        $assigneeId = trim((string) ($action['assignee_id'] ?? '')) ?: null;

        $payload = [
            'request_no' => $requestNo,
            'guest_name' => $guestName,
            'guest_email' => trim((string) ($action['guest_email'] ?? '')) ?: null,
            'guest_phone' => trim((string) ($action['guest_phone'] ?? '')) ?: null,
            'room_id' => trim((string) ($action['room_id'] ?? '')) ?: null,
            'room_number' => $roomNumber,
            'reservation_id' => $reservationId,
            'stay_code' => trim((string) ($action['stay_code'] ?? '')) ?: null,
            'category' => $category,
            'title' => $title,
            'description' => trim((string) ($action['description'] ?? '')) ?: null,
            'priority' => $priority,
            'scheduled_at' => $scheduledAt !== '' ? $scheduledAt : null,
            'assignee_type' => $assigneeType,
            'assignee_name' => $assigneeName !== '' ? $assigneeName : null,
            'assignee_id' => $assigneeId,
            'internal_notes' => trim((string) ($action['internal_notes'] ?? '')) ?: null,
            'requested_at' => (string) ($existing?->payload['requested_at'] ?? now()->toIso8601String()),
            'completed_at' => $existing?->payload['completed_at'] ?? null,
            'cancelled_at' => $existing?->payload['cancelled_at'] ?? null,
            'status_history' => is_array($existing?->payload['status_history'] ?? null)
                ? $existing->payload['status_history']
                : [],
            'status' => $status,
        ];

        if ($isNew) {
            $payload = $this->appendConciergeHistory($payload, $status, $assigneeName !== '' ? $assigneeName : null);
        } else {
            $prevStatus = (string) ($existing?->status ?? ($existing?->payload['status'] ?? 'new'));
            if ($prevStatus !== $status) {
                $payload = $this->appendConciergeHistory($payload, $status, $assigneeName !== '' ? $assigneeName : null);
            }
        }

        $this->save($store, 'concierge_request', $id, $payload, $reservationId, $status);
    }

    /** @param  array<string, mixed>  $action */
    private function deleteConciergeRequest(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'concierge_request')
            ->where('code', $id)
            ->delete();
    }

    /** @param  array<string, mixed>  $action */
    private function setConciergeStatus(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $status = strtolower(trim((string) ($action['status'] ?? '')));
        if (! in_array($status, $this->conciergeStatuses(), true)) {
            throw ValidationException::withMessages(['status' => ['Statut invalide.']]);
        }

        $row = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'concierge_request')
            ->where('code', $id)
            ->first();
        if ($row === null) {
            throw ValidationException::withMessages(['id' => ['Demande introuvable.']]);
        }

        $payload = $row->payload ?? [];
        $prevStatus = (string) ($row->status ?? ($payload['status'] ?? 'new'));
        if ($prevStatus !== $status) {
            $by = trim((string) ($action['by'] ?? ($payload['assignee_name'] ?? ''))) ?: null;
            $payload = $this->appendConciergeHistory($payload, $status, $by);
        } else {
            $payload['status'] = $status;
        }
        $this->save(
            $store,
            'concierge_request',
            $id,
            $payload,
            $row->parent_code,
            $status,
        );
    }

    private function ensureHotelSettings(Store $store): void
    {
        $exists = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'hotel_settings')
            ->where('code', 'hotel-settings')
            ->exists();
        if ($exists) {
            return;
        }

        $this->save($store, 'hotel_settings', 'hotel-settings', $this->defaultHotelSettings(), null, 'active');
    }

    /** @return array<string, mixed> */
    private function defaultHotelSettings(): array
    {
        return [
            'check_in_time' => '14:00',
            'check_out_time' => '12:00',
            'early_arrival_limit' => '08:00',
            'early_arrival_fee_cents' => 0,
            'late_departure_limit' => '18:00',
            'late_departure_fee_cents' => 0,
            'deposit_amount_cents' => 0,
            'free_cancel_hours' => 24,
            'cancel_penalty_percent' => 100,
            'charge_no_shows' => true,
            'no_show_penalty_percent' => 100,
            'vat_enabled' => true,
            'vat_rate' => 10,
            'tc_enabled' => true,
            'tc_rate' => 5,
            'room_price_tax_inclusive' => false,
            'occupancy_tax_enabled' => false,
            'service_fee_enabled' => false,
            'currency_code' => 'USD',
            'currency_symbol' => '$',
            'currency_symbol_position' => 'before',
            'allow_overbooking' => false,
            'hk_shift_start' => '08:00',
            'hk_shift_end' => '17:00',
            'auto_dirty_on_checkout' => true,
            'notify_arrival' => true,
            'notify_departure' => true,
            'notify_new_reservation' => true,
            'notify_unpaid_balance' => true,
            'saved_at' => null,
        ];
    }

    /** @param  array<string, mixed>  $action */
    private function upsertHotelSettings(Store $store, array $action): void
    {
        $defaults = $this->defaultHotelSettings();
        $timeKeys = [
            'check_in_time',
            'check_out_time',
            'early_arrival_limit',
            'late_departure_limit',
            'hk_shift_start',
            'hk_shift_end',
        ];
        foreach ($timeKeys as $key) {
            $value = trim((string) ($action[$key] ?? $defaults[$key]));
            if (! preg_match('/^\d{2}:\d{2}$/', $value)) {
                throw ValidationException::withMessages([$key => ['Heure invalide.']]);
            }
            $defaults[$key] = $value;
        }

        $defaults['early_arrival_fee_cents'] = max(0, (int) ($action['early_arrival_fee_cents'] ?? 0));
        $defaults['late_departure_fee_cents'] = max(0, (int) ($action['late_departure_fee_cents'] ?? 0));
        $defaults['deposit_amount_cents'] = max(0, (int) ($action['deposit_amount_cents'] ?? 0));
        $defaults['free_cancel_hours'] = max(0, (int) ($action['free_cancel_hours'] ?? 24));
        $defaults['cancel_penalty_percent'] = max(0, min(100, (int) ($action['cancel_penalty_percent'] ?? 100)));
        $defaults['charge_no_shows'] = (bool) ($action['charge_no_shows'] ?? true);
        $defaults['no_show_penalty_percent'] = max(0, min(100, (int) ($action['no_show_penalty_percent'] ?? 100)));
        $defaults['vat_enabled'] = (bool) ($action['vat_enabled'] ?? true);
        $defaults['vat_rate'] = max(0, min(100, (float) ($action['vat_rate'] ?? 10)));
        $defaults['tc_enabled'] = (bool) ($action['tc_enabled'] ?? true);
        $defaults['tc_rate'] = max(0, min(100, (float) ($action['tc_rate'] ?? 5)));
        $defaults['room_price_tax_inclusive'] = (bool) ($action['room_price_tax_inclusive'] ?? false);
        $defaults['occupancy_tax_enabled'] = (bool) ($action['occupancy_tax_enabled'] ?? false);
        $defaults['service_fee_enabled'] = (bool) ($action['service_fee_enabled'] ?? false);

        $code = strtoupper(trim((string) ($action['currency_code'] ?? 'USD')));
        if ($code === '' || ! preg_match('/^[A-Z]{3}$/', $code)) {
            throw ValidationException::withMessages(['currency_code' => ['Code devise invalide.']]);
        }
        $symbol = trim((string) ($action['currency_symbol'] ?? '$'));
        if ($symbol === '') {
            $symbol = $code;
        }
        $position = (string) ($action['currency_symbol_position'] ?? 'before');
        if (! in_array($position, ['before', 'after'], true)) {
            $position = 'before';
        }
        $defaults['currency_code'] = $code;
        $defaults['currency_symbol'] = mb_substr($symbol, 0, 8);
        $defaults['currency_symbol_position'] = $position;
        $defaults['allow_overbooking'] = (bool) ($action['allow_overbooking'] ?? false);
        $defaults['auto_dirty_on_checkout'] = (bool) ($action['auto_dirty_on_checkout'] ?? true);
        $defaults['notify_arrival'] = (bool) ($action['notify_arrival'] ?? true);
        $defaults['notify_departure'] = (bool) ($action['notify_departure'] ?? true);
        $defaults['notify_new_reservation'] = (bool) ($action['notify_new_reservation'] ?? true);
        $defaults['notify_unpaid_balance'] = (bool) ($action['notify_unpaid_balance'] ?? true);
        $defaults['saved_at'] = now()->toIso8601String();

        $this->save($store, 'hotel_settings', 'hotel-settings', $defaults, null, 'active');
    }

    /** @return array<string, mixed> */
    private function hotelSettings(Store $store): array
    {
        $this->ensureHotelSettings($store);
        $row = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'hotel_settings')
            ->where('code', 'hotel-settings')
            ->first();

        return array_merge($this->defaultHotelSettings(), $row?->payload ?? []);
    }

    /**
     * @param  array<string, mixed>  $settings
     * @return array{ht_cents: int, vat_cents: int, tc_cents: int, total_cents: int}
     */
    private function computeStayTaxes(int $enteredCents, array $settings): array
    {
        $entered = max(0, $enteredCents);
        $vatRate = ! empty($settings['vat_enabled']) ? (float) ($settings['vat_rate'] ?? 0) : 0.0;
        $tcRate = ! empty($settings['tc_enabled']) ? (float) ($settings['tc_rate'] ?? 0) : 0.0;
        $inclusive = (bool) ($settings['room_price_tax_inclusive'] ?? false);

        if ($inclusive) {
            $divisor = 1 + (($vatRate + $tcRate) / 100);
            $ht = $divisor > 0 ? (int) round($entered / $divisor) : $entered;
            $vat = (int) round($ht * ($vatRate / 100));
            $tc = (int) round($ht * ($tcRate / 100));

            return [
                'ht_cents' => $ht,
                'vat_cents' => $vat,
                'tc_cents' => $tc,
                'total_cents' => $entered,
            ];
        }

        $vat = (int) round($entered * ($vatRate / 100));
        $tc = (int) round($entered * ($tcRate / 100));

        return [
            'ht_cents' => $entered,
            'vat_cents' => $vat,
            'tc_cents' => $tc,
            'total_cents' => $entered + $vat + $tc,
        ];
    }

    private function assertTypeCapacity(
        Store $store,
        string $typeId,
        \Carbon\Carbon $arrive,
        \Carbon\Carbon $depart,
        ?string $exceptReservationId = null,
    ): void {
        $settings = $this->hotelSettings($store);
        if (! empty($settings['allow_overbooking'])) {
            return;
        }

        $capacity = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room')
            ->get()
            ->filter(function (DeskDocument $doc) use ($typeId) {
                $payload = $doc->payload ?? [];
                if (($payload['is_active'] ?? true) === false) {
                    return false;
                }
                if ((string) ($payload['housekeeping_status'] ?? 'clean') === 'out_of_service') {
                    return false;
                }

                return (string) ($payload['type_id'] ?? '') === $typeId;
            })
            ->count();

        if ($capacity < 1) {
            return;
        }

        $overlapping = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'reservation')
            ->get()
            ->filter(function (DeskDocument $doc) use ($typeId, $arrive, $depart, $exceptReservationId) {
                if ($exceptReservationId !== null && $doc->code === $exceptReservationId) {
                    return false;
                }
                $status = (string) ($doc->status ?? ($doc->payload['status'] ?? ''));
                if (! in_array($status, ['confirmed', 'reserved', 'checked_in', 'guaranteed'], true)) {
                    return false;
                }
                $payload = $doc->payload ?? [];
                if ((string) ($payload['type_id'] ?? '') !== $typeId) {
                    return false;
                }
                try {
                    $rowArrive = \Carbon\Carbon::parse((string) ($payload['arrive_on'] ?? ''))->startOfDay();
                    $rowDepart = \Carbon\Carbon::parse((string) ($payload['depart_on'] ?? ''))->startOfDay();
                } catch (\Throwable) {
                    return false;
                }

                return $rowArrive->lt($depart) && $rowDepart->gt($arrive);
            })
            ->count();

        if ($overlapping >= $capacity) {
            throw ValidationException::withMessages([
                'type_id' => ['Capacité dépassée pour ces dates. Activez le surbooking ou choisissez un autre type.'],
            ]);
        }
    }

    /** @param  array<string, mixed>  $settings */
    private function maybeEarlyArrivalFeeCents(array $settings): int
    {
        $limit = (string) ($settings['early_arrival_limit'] ?? '08:00');
        $fee = max(0, (int) ($settings['early_arrival_fee_cents'] ?? 0));
        if ($fee < 1) {
            return 0;
        }
        $now = now();
        try {
            $threshold = $now->copy()->setTimeFromTimeString($limit.':00');
        } catch (\Throwable) {
            return 0;
        }

        return $now->lt($threshold) ? $fee : 0;
    }

    /** @param  array<string, mixed>  $settings */
    private function maybeLateDepartureFeeCents(array $settings): int
    {
        $limit = (string) ($settings['late_departure_limit'] ?? '18:00');
        $fee = max(0, (int) ($settings['late_departure_fee_cents'] ?? 0));
        if ($fee < 1) {
            return 0;
        }
        $now = now();
        try {
            $threshold = $now->copy()->setTimeFromTimeString($limit.':00');
        } catch (\Throwable) {
            return 0;
        }

        return $now->gt($threshold) ? $fee : 0;
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
            'type_id' => $room['type_id'] ?? null,
            'type_name' => $room['type_name'] ?? '',
            'space_kind' => $room['space_kind'] ?? 'guest_room',
            'guest_name' => $this->required($action, 'guest_name'),
            'arrive_on' => $action['arrive_on'] ?? now()->toIso8601String(),
            'depart_on' => $action['depart_on'] ?? null,
            'adults' => 2,
            'children' => 0,
            'channel' => 'direct',
            'status' => 'confirmed',
        ], (string) $room['id'], 'confirmed');
        $room['status'] = 'reserved';
        $this->save($store, 'room', (string) $room['id'], $room, null, 'reserved');
    }

    /** @return list<string> */
    private function reservationChannels(): array
    {
        return ['direct', 'phone', 'walk_in', 'agency', 'booking_com', 'expedia', 'other'];
    }

    /** @param  array<string, mixed>  $action */
    private function upsertReservation(Store $store, array $action): void
    {
        $id = (string) ($action['id'] ?? '');
        $isNew = $id === '';
        if ($isNew) {
            $id = (string) Str::uuid();
        }

        $existing = null;
        if (! $isNew) {
            $existing = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('kind', 'reservation')
                ->where('code', $id)
                ->first();
            if ($existing === null) {
                throw ValidationException::withMessages(['id' => ['Réservation introuvable.']]);
            }
            $currentStatus = (string) ($existing->status ?? ($existing->payload['status'] ?? 'confirmed'));
            if (in_array($currentStatus, ['checked_in', 'checked_out'], true)) {
                throw ValidationException::withMessages(['id' => ['Réservation déjà en séjour ou terminée.']]);
            }
        }

        $spaceKind = (string) ($action['space_kind'] ?? 'guest_room');
        if (! in_array($spaceKind, ['guest_room', 'conference', 'reception'], true)) {
            throw ValidationException::withMessages(['space_kind' => ['Type d’espace invalide.']]);
        }

        $typeId = $this->required($action, 'type_id');
        $type = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'room_type')
            ->where('code', $typeId)
            ->first();
        if ($type === null) {
            throw ValidationException::withMessages(['type_id' => ['Type de chambre introuvable.']]);
        }

        $arriveOn = (string) ($action['arrive_on'] ?? '');
        $departOn = (string) ($action['depart_on'] ?? '');
        if ($arriveOn === '') {
            throw ValidationException::withMessages(['arrive_on' => ['Date d’arrivée requise.']]);
        }
        if ($departOn === '') {
            throw ValidationException::withMessages(['depart_on' => ['Date de départ requise.']]);
        }
        try {
            $arrive = \Carbon\Carbon::parse($arriveOn)->startOfDay();
            $depart = \Carbon\Carbon::parse($departOn)->startOfDay();
        } catch (\Throwable) {
            throw ValidationException::withMessages(['arrive_on' => ['Dates invalides.']]);
        }
        if ($depart->lte($arrive)) {
            throw ValidationException::withMessages(['depart_on' => ['Le départ doit être après l’arrivée.']]);
        }

        $guestName = trim((string) ($action['guest_name'] ?? ''));
        if ($guestName === '') {
            throw ValidationException::withMessages(['guest_name' => ['Nom du client requis.']]);
        }

        $channel = (string) ($action['channel'] ?? 'direct');
        if (! in_array($channel, $this->reservationChannels(), true)) {
            $channel = 'direct';
        }

        $adults = max(1, (int) ($action['adults'] ?? 2));
        $children = max(0, (int) ($action['children'] ?? 0));
        $settings = $this->hotelSettings($store);
        $this->assertTypeCapacity($store, $typeId, $arrive, $depart, $isNew ? null : $id);

        $depositCents = isset($action['deposit_cents']) && $action['deposit_cents'] !== null && $action['deposit_cents'] !== ''
            ? max(0, (int) $action['deposit_cents'])
            : (int) ($settings['deposit_amount_cents'] ?? 0);

        $customerId = trim((string) ($action['customer_id'] ?? ''));
        $guestEmail = trim((string) ($action['guest_email'] ?? ''));
        $guestPhone = trim((string) ($action['guest_phone'] ?? ''));
        $specialRequests = trim((string) ($action['special_requests'] ?? ''));

        $status = 'confirmed';
        if ($existing !== null) {
            $prev = (string) ($existing->status ?? ($existing->payload['status'] ?? 'confirmed'));
            if ($prev === 'cancelled') {
                $status = 'cancelled';
            }
        }

        $stayCode = (string) ($existing?->payload['stay_code'] ?? '');
        if ($stayCode === '') {
            $stayCode = $this->nextBookingCode();
        }
        $reservationNo = (string) ($existing?->payload['reservation_no'] ?? '');
        if ($reservationNo === '') {
            $reservationNo = $this->nextReservationNo($store);
        }

        $this->save($store, 'reservation', $id, [
            'customer_id' => $customerId !== '' ? $customerId : null,
            'guest_name' => $guestName,
            'guest_email' => $guestEmail !== '' ? $guestEmail : null,
            'guest_phone' => $guestPhone !== '' ? $guestPhone : null,
            'space_kind' => $spaceKind,
            'type_id' => $typeId,
            'type_name' => (string) ($type->payload['name'] ?? $typeId),
            'type_rate_cents' => (int) ($type->payload['base_price_cents'] ?? $type->payload['rate'] ?? 0),
            'type_currency' => (string) ($type->payload['currency'] ?? $settings['currency_code'] ?? 'USD'),
            'check_in_time' => (string) ($settings['check_in_time'] ?? '14:00'),
            'check_out_time' => (string) ($settings['check_out_time'] ?? '12:00'),
            'room_id' => $existing?->payload['room_id'] ?? null,
            'room_number' => $existing?->payload['room_number'] ?? null,
            'arrive_on' => $arrive->toDateString(),
            'depart_on' => $depart->toDateString(),
            'nights' => $arrive->diffInDays($depart),
            'adults' => $adults,
            'children' => $children,
            'deposit_cents' => $depositCents,
            'deposit_collected_cents' => (int) ($existing?->payload['deposit_collected_cents'] ?? 0),
            'channel' => $channel,
            'special_requests' => $specialRequests !== '' ? $specialRequests : null,
            'stay_code' => $stayCode,
            'reservation_no' => $reservationNo,
            'status' => $status,
        ], $typeId, $status);
    }

    private function nextBookingCode(): string
    {
        return 'BKG-'.now()->format('Y').'-'.strtoupper(Str::random(6));
    }

    private function nextReservationNo(Store $store): string
    {
        $count = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'reservation')
            ->count() + 1;

        return 'RES-'.str_pad((string) $count, 3, '0', STR_PAD_LEFT);
    }

    /** @param  array<string, mixed>  $action */
    private function deleteReservation(Store $store, array $action): void
    {
        $id = $this->required($action, 'id');
        $reservation = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'reservation')
            ->where('code', $id)
            ->first();
        if ($reservation === null) {
            throw ValidationException::withMessages(['id' => ['Réservation introuvable.']]);
        }
        $status = (string) ($reservation->status ?? ($reservation->payload['status'] ?? ''));
        if (in_array($status, ['checked_in', 'checked_out'], true)) {
            throw ValidationException::withMessages(['id' => ['Impossible de supprimer une réservation en séjour ou terminée.']]);
        }

        $settings = $this->hotelSettings($store);
        $arriveOn = (string) ($reservation->payload['arrive_on'] ?? '');
        if ($arriveOn !== '') {
            try {
                $arrive = \Carbon\Carbon::parse($arriveOn)->startOfDay()->setTimeFromTimeString(
                    ((string) ($settings['check_in_time'] ?? '14:00')).':00'
                );
                $freeHours = max(0, (int) ($settings['free_cancel_hours'] ?? 24));
                $hoursUntil = now()->floatDiffInHours($arrive, false);
                if ($hoursUntil < $freeHours) {
                    $nights = max(1, (int) ($reservation->payload['nights'] ?? 1));
                    $rate = (int) ($reservation->payload['type_rate_cents'] ?? 0);
                    $penaltyPct = max(0, min(100, (int) ($settings['cancel_penalty_percent'] ?? 100)));
                    $penalty = (int) round(($nights > 0 ? $rate : 0) * ($penaltyPct / 100));
                    if ($penalty > 0 && empty($action['force'])) {
                        throw ValidationException::withMessages([
                            'id' => [
                                'Annulation hors fenêtre gratuite ('.$freeHours.'h). Pénalité estimée : '
                                .number_format($penalty / 100, 2, '.', ' ')
                                .' '.($reservation->payload['type_currency'] ?? $settings['currency_code'] ?? '')
                                .'. Confirmez avec force=1 pour poursuivre.',
                            ],
                        ]);
                    }
                }
            } catch (ValidationException $e) {
                throw $e;
            } catch (\Throwable) {
                // ignore parse errors for delete
            }
        }

        $roomId = $reservation->payload['room_id'] ?? null;
        DeskDocument::query()->where('store_id', $store->id)->where('code', $id)->where('kind', 'reservation')->delete();

        if (is_string($roomId) && $roomId !== '') {
            $room = DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('kind', 'room')
                ->where('code', $roomId)
                ->first();
            if ($room !== null && ($room->status ?? '') === 'reserved') {
                $payload = $room->payload ?? [];
                $payload['status'] = 'vacant';
                $this->save($store, 'room', $roomId, $payload, $room->parent_code, 'vacant');
            }
        }
    }

    /** @param  array<string, mixed>  $action */
    private function checkIn(Store $store, array $action): void
    {
        $reservation = $this->doc($store, $this->required($action, 'reservation_id'));
        $status = (string) ($reservation['status'] ?? '');
        if (! in_array($status, ['reserved', 'confirmed'], true)) {
            throw ValidationException::withMessages(['reservation_id' => ['Réservation non ouvrable.']]);
        }

        $roomId = (string) ($action['room_id'] ?? $reservation['room_id'] ?? '');
        if ($roomId === '') {
            throw ValidationException::withMessages(['room_id' => ['Attribuez une chambre à l’arrivée.']]);
        }
        $room = $this->doc($store, $roomId);
        if (($room['status'] ?? '') === 'occupied') {
            throw ValidationException::withMessages(['room_id' => ['Chambre occupée.']]);
        }

        $settings = $this->hotelSettings($store);
        $arriveOn = (string) ($reservation['arrive_on'] ?? now()->toDateString());
        $departOn = (string) ($reservation['depart_on'] ?? '');
        try {
            $arrive = \Carbon\Carbon::parse($arriveOn)->startOfDay();
            $depart = $departOn !== ''
                ? \Carbon\Carbon::parse($departOn)->startOfDay()
                : $arrive->copy()->addDay();
        } catch (\Throwable) {
            $arrive = now()->startOfDay();
            $depart = $arrive->copy()->addDay();
        }
        $typeId = (string) ($reservation['type_id'] ?? $room['type_id'] ?? '');
        if ($typeId !== '') {
            $this->assertTypeCapacity($store, $typeId, $arrive, $depart, (string) $reservation['id']);
        }

        $nights = max(1, (int) ($reservation['nights'] ?? $arrive->diffInDays($depart)));
        $rate = (int) ($reservation['type_rate_cents'] ?? 0);
        $subtotal = $rate * $nights;
        $taxes = $this->computeStayTaxes($subtotal, $settings);
        $earlyFee = $this->maybeEarlyArrivalFeeCents($settings);

        $folioLines = [];
        if ($taxes['ht_cents'] > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'room',
                'description' => 'Séjour '.$arrive->toDateString().' → '.$depart->toDateString(),
                'amount' => $taxes['ht_cents'],
                'created_at' => now()->toIso8601String(),
            ];
        }
        if ($taxes['vat_cents'] > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'vat',
                'description' => 'TVA '.((float) ($settings['vat_rate'] ?? 0)).'%',
                'amount' => $taxes['vat_cents'],
                'created_at' => now()->toIso8601String(),
            ];
        }
        if ($taxes['tc_cents'] > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'tc',
                'description' => 'TC '.((float) ($settings['tc_rate'] ?? 0)).'%',
                'amount' => $taxes['tc_cents'],
                'created_at' => now()->toIso8601String(),
            ];
        }
        if ($earlyFee > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'early_arrival',
                'description' => 'Frais d\'arrivée anticipée',
                'amount' => $earlyFee,
                'created_at' => now()->toIso8601String(),
            ];
        }

        $folioId = (string) Str::uuid();
        $this->save($store, 'folio', $folioId, [
            'room_id' => $room['id'],
            'room_number' => $room['number'] ?? '',
            'reservation_id' => $reservation['id'],
            'guest_name' => $reservation['guest_name'] ?? '',
            'status' => 'open',
            'amount_due_cents' => $taxes['total_cents'] + $earlyFee,
            'lines' => $folioLines,
        ], (string) $room['id'], 'open');
        $reservation['status'] = 'checked_in';
        $reservation['folio_id'] = $folioId;
        $reservation['room_id'] = $room['id'];
        $reservation['room_number'] = $room['number'] ?? '';
        $reservation['checked_in_at'] = now()->toIso8601String();
        $reservation['check_in_time'] = (string) ($settings['check_in_time'] ?? '14:00');
        $reservation['check_out_time'] = (string) ($settings['check_out_time'] ?? '12:00');
        $reservation['room_subtotal_cents'] = $taxes['ht_cents'];
        $reservation['vat_cents'] = $taxes['vat_cents'];
        $reservation['tc_cents'] = $taxes['tc_cents'];
        $reservation['amount_due_cents'] = $taxes['total_cents'] + $earlyFee;
        $reservation['type_currency'] = (string) ($reservation['type_currency'] ?? $settings['currency_code'] ?? 'USD');
        if (empty($reservation['deposit_cents'])) {
            $reservation['deposit_cents'] = (int) ($settings['deposit_amount_cents'] ?? 0);
        }
        $this->save($store, 'reservation', (string) $reservation['id'], $reservation, (string) $room['id'], 'checked_in');
        $room['status'] = 'occupied';
        $room['guest_name'] = $reservation['guest_name'] ?? '';
        $room['folio_id'] = $folioId;
        $this->save($store, 'room', (string) $room['id'], $room, null, 'occupied');
    }

    /** @param  array<string, mixed>  $action */
    private function walkInCheckIn(Store $store, array $action): void
    {
        $guestName = trim((string) ($action['guest_name'] ?? ''));
        if ($guestName === '') {
            throw ValidationException::withMessages(['guest_name' => ['Nom du client requis.']]);
        }

        $nationality = trim((string) ($action['nationality'] ?? ''));
        if ($nationality === '') {
            throw ValidationException::withMessages(['nationality' => ['La nationalité est requise.']]);
        }

        $documentType = strtolower(trim((string) ($action['id_document_type'] ?? '')));
        if (! in_array($documentType, $this->idDocumentTypes(), true)) {
            throw ValidationException::withMessages(['id_document_type' => ['Type de document invalide.']]);
        }

        $documentNumber = trim((string) ($action['id_document_number'] ?? ''));
        if ($documentNumber === '') {
            throw ValidationException::withMessages(['id_document_number' => ['Le numéro de pièce est requis.']]);
        }

        $room = $this->doc($store, $this->required($action, 'room_id'));
        if (($room['status'] ?? '') === 'occupied') {
            throw ValidationException::withMessages(['room_id' => ['Chambre occupée.']]);
        }
        if (($room['is_active'] ?? true) === false) {
            throw ValidationException::withMessages(['room_id' => ['Chambre inactive.']]);
        }

        $arriveOn = (string) ($action['arrive_on'] ?? now()->toDateString());
        $departOn = (string) ($action['depart_on'] ?? '');
        if ($departOn === '') {
            throw ValidationException::withMessages(['depart_on' => ['Date de départ requise.']]);
        }
        try {
            $arrive = \Carbon\Carbon::parse($arriveOn)->startOfDay();
            $depart = \Carbon\Carbon::parse($departOn)->startOfDay();
        } catch (\Throwable) {
            throw ValidationException::withMessages(['arrive_on' => ['Dates invalides.']]);
        }
        if ($depart->lte($arrive)) {
            throw ValidationException::withMessages(['depart_on' => ['Le départ doit être après l’arrivée.']]);
        }

        $settings = $this->hotelSettings($store);

        $typeId = (string) ($room['type_id'] ?? $action['type_id'] ?? '');
        if ($typeId !== '') {
            $this->assertTypeCapacity($store, $typeId, $arrive, $depart);
        }
        $type = $typeId !== ''
            ? DeskDocument::query()
                ->where('store_id', $store->id)
                ->where('kind', 'room_type')
                ->where('code', $typeId)
                ->first()
            : null;

        $customerId = trim((string) ($action['customer_id'] ?? ''));
        $reservationId = (string) Str::uuid();
        $folioId = (string) Str::uuid();
        $nights = max(1, $arrive->diffInDays($depart));
        $rate = (int) ($type?->payload['base_price_cents'] ?? $type?->payload['rate'] ?? $room['type_rate_cents'] ?? $room['price_override_cents'] ?? 0);
        $special = isset($action['special_price_cents']) && $action['special_price_cents'] !== null && $action['special_price_cents'] !== ''
            ? max(0, (int) $action['special_price_cents'])
            : null;
        $enteredSubtotal = $special ?? ($rate * $nights);
        $taxes = $this->computeStayTaxes($enteredSubtotal, $settings);
        $earlyFee = $this->maybeEarlyArrivalFeeCents($settings);
        $depositCents = isset($action['deposit_cents']) && $action['deposit_cents'] !== null && $action['deposit_cents'] !== ''
            ? max(0, (int) $action['deposit_cents'])
            : (int) ($settings['deposit_amount_cents'] ?? 0);
        $currency = (string) ($type?->payload['currency'] ?? $room['type_currency'] ?? $settings['currency_code'] ?? 'USD');

        $payload = [
            'customer_id' => $customerId !== '' ? $customerId : null,
            'guest_name' => $guestName,
            'guest_email' => trim((string) ($action['guest_email'] ?? '')) ?: null,
            'guest_phone' => trim((string) ($action['guest_phone'] ?? '')) ?: null,
            'birth_place' => trim((string) ($action['birth_place'] ?? '')) ?: null,
            'date_of_birth' => trim((string) ($action['date_of_birth'] ?? '')) ?: null,
            'nationality' => $nationality,
            'residence' => trim((string) ($action['residence'] ?? '')) ?: null,
            'profession' => trim((string) ($action['profession'] ?? '')) ?: null,
            'company_name' => trim((string) ($action['company_name'] ?? '')) ?: null,
            'contact_person' => trim((string) ($action['contact_person'] ?? '')) ?: null,
            'origin_place' => trim((string) ($action['origin_place'] ?? '')) ?: null,
            'id_document_type' => $documentType,
            'id_document_number' => $documentNumber,
            'id_document_issue_place' => trim((string) ($action['id_document_issue_place'] ?? '')) ?: null,
            'id_document_name' => trim((string) ($action['id_document_name'] ?? '')) ?: null,
            'space_kind' => $room['space_kind'] ?? ($type?->payload['space_kind'] ?? 'guest_room'),
            'type_id' => $typeId !== '' ? $typeId : null,
            'type_name' => (string) ($type?->payload['name'] ?? $room['type_name'] ?? ''),
            'type_rate_cents' => $rate,
            'type_currency' => $currency,
            'room_id' => $room['id'],
            'room_number' => $room['number'] ?? '',
            'arrive_on' => $arrive->toDateString(),
            'depart_on' => $depart->toDateString(),
            'nights' => $nights,
            'adults' => max(1, (int) ($action['adults'] ?? 1)),
            'children' => max(0, (int) ($action['children'] ?? 0)),
            'channel' => in_array((string) ($action['channel'] ?? 'walk_in'), ['direct', 'phone', 'walk_in', 'agency', 'booking_com', 'expedia', 'other'], true)
                ? (string) ($action['channel'] ?? 'walk_in')
                : 'walk_in',
            'walk_in' => true,
            'stay_code' => $this->nextStayCode($store),
            'sign_token' => (string) Str::lower(Str::random(40)),
            'guest_signed_at' => null,
            'purpose' => trim((string) ($action['purpose'] ?? '')) ?: null,
            'companions' => trim((string) ($action['companions'] ?? '')) ?: null,
            'special_requests' => trim((string) ($action['special_requests'] ?? '')) ?: null,
            'payment_mode' => in_array((string) ($action['payment_mode'] ?? 'collect_now'), ['collect_now', 'credit'], true)
                ? (string) ($action['payment_mode'] ?? 'collect_now')
                : 'collect_now',
            'amount_due_cents' => $taxes['total_cents'] + $earlyFee,
            'amount_collected_cents' => max(0, (int) ($action['amount_collected_cents'] ?? 0)),
            'room_subtotal_cents' => $taxes['ht_cents'],
            'vat_cents' => $taxes['vat_cents'],
            'tc_cents' => $taxes['tc_cents'],
            'payment_method' => trim((string) ($action['payment_method'] ?? '')) ?: null,
            'voucher_reference' => trim((string) ($action['voucher_reference'] ?? '')) ?: null,
            'deposit_cents' => $depositCents,
            'special_price_cents' => $special,
            'special_price_reason' => trim((string) ($action['special_price_reason'] ?? '')) ?: null,
            'receptionist_name' => trim((string) ($action['receptionist_name'] ?? '')) ?: null,
            'guest_signature_mode' => in_array((string) ($action['guest_signature_mode'] ?? 'dotted'), ['upload', 'blank', 'dotted'], true)
                ? (string) ($action['guest_signature_mode'] ?? 'dotted')
                : 'dotted',
            'guest_signature_name' => trim((string) ($action['guest_signature_name'] ?? '')) ?: null,
            'guest_signature_data' => is_string($action['guest_signature_data'] ?? null) && strlen((string) $action['guest_signature_data']) <= 600_000
                ? (string) $action['guest_signature_data']
                : null,
            'check_in_time' => (string) ($settings['check_in_time'] ?? '14:00'),
            'check_out_time' => (string) ($settings['check_out_time'] ?? '12:00'),
            'checked_in_at' => now()->toIso8601String(),
            'folio_id' => $folioId,
            'status' => 'checked_in',
        ];

        if (($payload['purpose'] ?? null) === null) {
            throw ValidationException::withMessages(['purpose' => ['Le motif du séjour est requis.']]);
        }

        $folioLines = [];
        if ($taxes['ht_cents'] > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'room',
                'description' => 'Séjour '.$arrive->toDateString().' → '.$depart->toDateString(),
                'amount' => $taxes['ht_cents'],
                'created_at' => now()->toIso8601String(),
            ];
        }
        if ($taxes['vat_cents'] > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'vat',
                'description' => 'TVA '.((float) ($settings['vat_rate'] ?? 0)).'%',
                'amount' => $taxes['vat_cents'],
                'created_at' => now()->toIso8601String(),
            ];
        }
        if ($taxes['tc_cents'] > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'tc',
                'description' => 'TC '.((float) ($settings['tc_rate'] ?? 0)).'%',
                'amount' => $taxes['tc_cents'],
                'created_at' => now()->toIso8601String(),
            ];
        }
        if ($earlyFee > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'early_arrival',
                'description' => 'Frais d\'arrivée anticipée',
                'amount' => $earlyFee,
                'created_at' => now()->toIso8601String(),
            ];
        }
        $collected = (int) $payload['amount_collected_cents'];
        if ($payload['payment_mode'] === 'collect_now' && $collected > 0) {
            $folioLines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'payment',
                'description' => 'Encaissement '.($payload['payment_method'] ?? 'cash'),
                'amount' => -$collected,
                'created_at' => now()->toIso8601String(),
            ];
        }

        $this->save($store, 'reservation', $reservationId, $payload, (string) $room['id'], 'checked_in');
        $this->save($store, 'folio', $folioId, [
            'room_id' => $room['id'],
            'room_number' => $room['number'] ?? '',
            'reservation_id' => $reservationId,
            'guest_name' => $guestName,
            'status' => 'open',
            'amount_due_cents' => $taxes['total_cents'] + $earlyFee,
            'amount_collected_cents' => $payload['payment_mode'] === 'collect_now' ? $collected : 0,
            'payment_mode' => $payload['payment_mode'],
            'lines' => $folioLines,
        ], (string) $room['id'], 'open');
        $room['status'] = 'occupied';
        $room['guest_name'] = $guestName;
        $room['folio_id'] = $folioId;
        $this->save($store, 'room', (string) $room['id'], $room, $room['building_id'] ?? null, 'occupied');
    }

    private function nextStayCode(Store $store): string
    {
        $count = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'reservation')
            ->count() + 1;

        return 'STY-'.str_pad((string) $count, 3, '0', STR_PAD_LEFT);
    }

    /** @param  array<string, mixed>  $action */
    private function createStaySignLink(Store $store, array $action): void
    {
        $id = $this->required($action, 'reservation_id');
        $reservation = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'reservation')
            ->where('code', $id)
            ->first();
        if ($reservation === null) {
            throw ValidationException::withMessages(['reservation_id' => ['Séjour introuvable.']]);
        }

        $payload = $reservation->payload ?? [];
        $status = (string) ($reservation->status ?? ($payload['status'] ?? ''));
        if (! in_array($status, ['checked_in', 'confirmed', 'reserved'], true)) {
            throw ValidationException::withMessages(['reservation_id' => ['Le séjour doit être en cours.']]);
        }

        if (empty($payload['sign_token'])) {
            $payload['sign_token'] = (string) Str::lower(Str::random(40));
        }
        if (empty($payload['stay_code'])) {
            $payload['stay_code'] = $this->nextStayCode($store);
        }
        // Keep active in-house stays as checked_in for signing.
        $persistStatus = $status === 'checked_in' ? 'checked_in' : $status;
        if (in_array($status, ['confirmed', 'reserved'], true) && ! empty($payload['room_id'])) {
            $persistStatus = 'checked_in';
            $payload['status'] = 'checked_in';
        }
        $this->save($store, 'reservation', $id, $payload, $reservation->parent_code, $persistStatus);
    }

    /** @param  array<string, mixed>  $action */
    private function submitStaySignature(Store $store, array $action): void
    {
        $id = $this->required($action, 'reservation_id');
        $signature = (string) ($action['guest_signature_data'] ?? '');
        if ($signature === '' || strlen($signature) > 600_000) {
            throw ValidationException::withMessages(['guest_signature_data' => ['Signature invalide.']]);
        }

        $reservation = DeskDocument::query()
            ->where('store_id', $store->id)
            ->where('kind', 'reservation')
            ->where('code', $id)
            ->first();
        if ($reservation === null) {
            throw ValidationException::withMessages(['reservation_id' => ['Séjour introuvable.']]);
        }

        $payload = $reservation->payload ?? [];
        $payload['guest_signature_mode'] = 'drawn';
        $payload['guest_signature_data'] = $signature;
        $payload['guest_signature_name'] = 'signature.png';
        $payload['guest_signed_at'] = now()->toIso8601String();
        $status = (string) ($reservation->status ?? ($payload['status'] ?? 'checked_in'));
        $this->save($store, 'reservation', $id, $payload, $reservation->parent_code, $status);
    }

    /** @return array<string, mixed> */
    public function stayBySignToken(string $token): array
    {
        $token = trim($token);
        if ($token === '' || strlen($token) < 20) {
            throw ValidationException::withMessages(['token' => ['Lien de signature invalide.']]);
        }

        $row = $this->findReservationBySignToken($token);
        if ($row === null) {
            throw ValidationException::withMessages(['token' => ['Lien de signature introuvable ou expiré.']]);
        }

        $doc = $this->present($row);
        $hasSignature = ! empty($doc['guest_signature_data']);
        unset($doc['guest_signature_data'], $doc['id_document_data']);

        $branding = [
            'brand_name' => 'Hotel',
            'logo_url' => null,
            'primary_color' => '#6D28D9',
        ];
        $store = Store::query()->find($row->store_id);
        if ($store !== null) {
            $tenant = Tenant::query()->find($store->tenant_id);
            if ($tenant !== null) {
                $from = TenantBranding::from($tenant);
                $branding = [
                    'brand_name' => $from['brand_name'],
                    'logo_url' => $from['logo_url'],
                    'primary_color' => $from['primary_color'],
                ];
            } elseif (is_string($store->name) && $store->name !== '') {
                $branding['brand_name'] = $store->name;
            }
        }

        return [
            'id' => $doc['id'],
            'guest_name' => $doc['guest_name'] ?? '',
            'room_number' => $doc['room_number'] ?? '',
            'stay_code' => $doc['stay_code'] ?? '',
            'type_name' => $doc['type_name'] ?? '',
            'arrive_on' => $doc['arrive_on'] ?? null,
            'depart_on' => $doc['depart_on'] ?? null,
            'checked_in_at' => $doc['checked_in_at'] ?? $row->updated_at?->toIso8601String(),
            'adults' => $doc['adults'] ?? 1,
            'children' => $doc['children'] ?? 0,
            'nights' => $doc['nights'] ?? null,
            'purpose' => $doc['purpose'] ?? null,
            'amount_due_cents' => $doc['amount_due_cents'] ?? 0,
            'room_subtotal_cents' => $doc['room_subtotal_cents'] ?? 0,
            'vat_cents' => $doc['vat_cents'] ?? 0,
            'tc_cents' => $doc['tc_cents'] ?? 0,
            'type_currency' => $doc['type_currency'] ?? 'USD',
            'guest_signed_at' => $doc['guest_signed_at'] ?? null,
            'has_signature' => $hasSignature,
            'hotel' => $branding,
        ];
    }

    /** @return array<string, mixed> */
    public function submitStaySignatureByToken(string $token, string $signatureData): array
    {
        $token = trim($token);
        if ($token === '' || strlen($token) < 20) {
            throw ValidationException::withMessages(['token' => ['Lien de signature invalide.']]);
        }
        if ($signatureData === '' || strlen($signatureData) > 600_000) {
            throw ValidationException::withMessages(['guest_signature_data' => ['Signature invalide.']]);
        }

        $row = $this->findReservationBySignToken($token);
        if ($row === null) {
            throw ValidationException::withMessages(['token' => ['Lien de signature introuvable ou expiré.']]);
        }

        $store = Store::query()->find($row->store_id);
        if ($store === null) {
            throw ValidationException::withMessages(['token' => ['Magasin introuvable.']]);
        }

        $payload = $row->payload ?? [];
        $payload['guest_signature_mode'] = 'drawn';
        $payload['guest_signature_data'] = $signatureData;
        $payload['guest_signature_name'] = 'signature.png';
        $payload['guest_signed_at'] = now()->toIso8601String();
        $this->save($store, 'reservation', (string) $row->code, $payload, $row->parent_code, 'checked_in');

        return $this->stayBySignToken($token);
    }

    private function findReservationBySignToken(string $token): ?DeskDocument
    {
        $row = DeskDocument::query()
            ->where('kind', 'reservation')
            ->where('payload->sign_token', $token)
            ->whereIn('status', ['checked_in', 'confirmed', 'reserved'])
            ->first();

        if ($row !== null) {
            return $row;
        }

        return DeskDocument::query()
            ->where('kind', 'reservation')
            ->where('payload->sign_token', $token)
            ->where(function ($q) {
                $q->where('payload->status', 'checked_in')
                    ->orWhere('payload->status', 'confirmed')
                    ->orWhere('payload->status', 'reserved');
            })
            ->first();
    }

    /** @return list<string> */
    private function idDocumentTypes(): array
    {
        return ['passport', 'national_id', 'driver_license', 'residence_permit', 'other'];
    }

    /** @param  array<string, mixed>  $action */
    private function checkOut(Store $store, array $action): void
    {
        $reservation = $this->doc($store, $this->required($action, 'reservation_id'));
        if (($reservation['status'] ?? '') !== 'checked_in') {
            throw ValidationException::withMessages(['reservation_id' => ['Aucun séjour en cours.']]);
        }
        $folio = $this->doc($store, (string) $reservation['folio_id']);
        $settings = $this->hotelSettings($store);
        $lateFee = $this->maybeLateDepartureFeeCents($settings);
        $lines = $folio['lines'] ?? [];
        if ($lateFee > 0) {
            $lines[] = [
                'id' => (string) Str::uuid(),
                'kind' => 'late_departure',
                'description' => 'Frais de départ tardif',
                'amount' => $lateFee,
                'created_at' => now()->toIso8601String(),
            ];
            $folio['lines'] = $lines;
            $folio['amount_due_cents'] = (int) ($folio['amount_due_cents'] ?? 0) + $lateFee;
        }

        $charges = collect($lines)->sum(fn ($line) => max(0, (int) ($line['amount'] ?? 0)));
        $paid = collect($lines)->sum(fn ($line) => max(0, -((int) ($line['amount'] ?? 0))));
        $balance = $charges - $paid;
        if ($balance > 0 && ! empty($settings['notify_unpaid_balance'])) {
            $reservation['unpaid_balance_warning'] = true;
            $reservation['unpaid_balance_cents'] = $balance;
        }

        $folio['status'] = 'closed';
        $folio['reference'] = 'HTL-'.strtoupper(Str::random(6));
        $this->save($store, 'folio', (string) $folio['id'], $folio, $folio['room_id'] ?? null, 'closed');
        $reservation['status'] = 'checked_out';
        $reservation['checked_out_at'] = now()->toIso8601String();
        $this->save($store, 'reservation', (string) $reservation['id'], $reservation, $reservation['room_id'] ?? null, 'checked_out');
        $room = $this->doc($store, (string) $reservation['room_id']);
        $room['status'] = 'vacant';
        if (! empty($settings['auto_dirty_on_checkout'])) {
            $room['housekeeping_status'] = 'dirty';
        }
        unset($room['guest_name'], $room['folio_id']);
        $this->save($store, 'room', (string) $room['id'], $room, $room['building_id'] ?? null, 'vacant');
        if (! empty($settings['auto_dirty_on_checkout'])) {
            $this->syncHousekeepingTaskForRoom($store, $room);
        }
    }

    /** @param  array<string, mixed>  $action */
    private function changeStayRoom(Store $store, array $action): void
    {
        $reservation = $this->doc($store, $this->required($action, 'reservation_id'));
        if (($reservation['status'] ?? '') !== 'checked_in') {
            throw ValidationException::withMessages(['reservation_id' => ['Séjour non ouvert.']]);
        }

        $newRoom = $this->doc($store, $this->required($action, 'room_id'));
        if (in_array((string) ($newRoom['status'] ?? ''), ['occupied', 'reserved'], true)) {
            throw ValidationException::withMessages(['room_id' => ['Chambre non disponible.']]);
        }
        if ((string) ($newRoom['housekeeping_status'] ?? 'clean') === 'out_of_service') {
            throw ValidationException::withMessages(['room_id' => ['Chambre hors service.']]);
        }

        $oldRoomId = (string) ($reservation['room_id'] ?? '');
        if ($oldRoomId !== '' && $oldRoomId === (string) $newRoom['id']) {
            return;
        }

        if ($oldRoomId !== '') {
            $oldRoom = $this->doc($store, $oldRoomId);
            $oldRoom['status'] = 'vacant';
            $dirtyOnChange = ! empty($this->hotelSettings($store)['auto_dirty_on_checkout']);
            if ($dirtyOnChange) {
                $oldRoom['housekeeping_status'] = 'dirty';
            }
            unset($oldRoom['guest_name'], $oldRoom['folio_id']);
            $this->save($store, 'room', $oldRoomId, $oldRoom, $oldRoom['building_id'] ?? null, 'vacant');
            if ($dirtyOnChange) {
                $this->syncHousekeepingTaskForRoom($store, $oldRoom);
            }
        }

        $folioId = (string) ($reservation['folio_id'] ?? '');
        if ($folioId !== '') {
            $folio = $this->doc($store, $folioId);
            $folio['room_id'] = $newRoom['id'];
            $folio['room_number'] = $newRoom['number'] ?? '';
            $this->save($store, 'folio', $folioId, $folio, (string) $newRoom['id'], (string) ($folio['status'] ?? 'open'));
            $newRoom['folio_id'] = $folioId;
        }

        $newRoom['status'] = 'occupied';
        $newRoom['guest_name'] = $reservation['guest_name'] ?? '';
        $this->save($store, 'room', (string) $newRoom['id'], $newRoom, $newRoom['building_id'] ?? null, 'occupied');

        $reservation['room_id'] = $newRoom['id'];
        $reservation['room_number'] = $newRoom['number'] ?? '';
        if (! empty($newRoom['type_id'])) {
            $reservation['type_id'] = $newRoom['type_id'];
            $reservation['type_name'] = $newRoom['type_name'] ?? ($reservation['type_name'] ?? '');
        }
        $this->save($store, 'reservation', (string) $reservation['id'], $reservation, (string) $newRoom['id'], 'checked_in');
    }

    /** @param  array<string, mixed>  $action */
    private function collectStayPayment(Store $store, array $action): void
    {
        $reservation = $this->doc($store, $this->required($action, 'reservation_id'));
        if (($reservation['status'] ?? '') !== 'checked_in') {
            throw ValidationException::withMessages(['reservation_id' => ['Séjour non ouvert.']]);
        }
        $roomId = (string) ($reservation['room_id'] ?? '');
        if ($roomId === '') {
            throw ValidationException::withMessages(['room_id' => ['Aucune chambre attribuée.']]);
        }
        $room = $this->doc($store, $roomId);
        $amount = max(0, (int) ($action['amount_cents'] ?? 0));
        if ($amount <= 0) {
            throw ValidationException::withMessages(['amount_cents' => ['Montant invalide.']]);
        }
        $method = trim((string) ($action['payment_method'] ?? 'cash')) ?: 'cash';

        $folioId = (string) ($room['folio_id'] ?? $reservation['folio_id'] ?? '');
        if ($folioId === '') {
            throw ValidationException::withMessages(['folio_id' => ['Aucun folio ouvert pour ce séjour.']]);
        }
        $folio = $this->doc($store, $folioId);
        $lines = $folio['lines'] ?? [];
        $lines[] = [
            'id' => (string) Str::uuid(),
            'kind' => 'payment',
            'description' => 'Encaissement — '.$method,
            'amount' => -$amount,
            'created_at' => now()->toIso8601String(),
            'by' => trim((string) ($action['by'] ?? '')) ?: null,
        ];
        $folio['lines'] = $lines;
        $this->save($store, 'folio', $folioId, $folio, $roomId, (string) ($folio['status'] ?? 'open'));

        if (empty($room['folio_id'])) {
            $room['folio_id'] = $folioId;
            $room['status'] = 'occupied';
            $this->save($store, 'room', $roomId, $room, $room['building_id'] ?? null, 'occupied');
        }

        $reservation['amount_collected_cents'] = (int) ($reservation['amount_collected_cents'] ?? 0) + $amount;
        $this->save($store, 'reservation', (string) $reservation['id'], $reservation, $roomId, 'checked_in');
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
