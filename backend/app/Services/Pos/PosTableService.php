<?php

namespace App\Services\Pos;

use App\Enums\PosTableStatus;
use App\Enums\SaleStatus;
use App\Models\PosReservation;
use App\Models\PosTable;
use App\Models\PosTableEvent;
use App\Models\PosTableZone;
use App\Models\Sale;
use App\Models\Store;
use App\Models\User;
use App\Services\Sales\SaleEngine;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class PosTableService
{
    public function __construct(
        private readonly SaleEngine $saleEngine,
    ) {}

    /**
     * @return array{zones: Collection<int, PosTableZone>, tables: Collection<int, PosTable>, stats: array<string, mixed>}
     */
    public function floor(Store $store): array
    {
        $zones = PosTableZone::query()
            ->where('store_id', $store->id)
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        $tables = PosTable::query()
            ->with([
                'zone:id,name',
                'currentSale.items',
                'currentSale.processedBy:id,name',
                'currentSale.customer:id,name',
                'reservations' => fn ($query) => $query
                    ->whereIn('status', ['pending', 'confirmed'])
                    ->orderBy('reserved_at')
                    ->with('customer:id,name,phone'),
            ])
            ->where('store_id', $store->id)
            ->orderBy('name')
            ->get();

        foreach ($tables as $table) {
            $table->syncOccupancy();
        }

        $tables = PosTable::query()
            ->with([
                'zone:id,name',
                'currentSale.items',
                'currentSale.processedBy:id,name',
                'currentSale.customer:id,name',
                'reservations' => fn ($query) => $query
                    ->whereIn('status', ['pending', 'confirmed'])
                    ->orderBy('reserved_at')
                    ->with('customer:id,name,phone'),
            ])
            ->where('store_id', $store->id)
            ->orderBy('name')
            ->get();

        return [
            'zones' => $zones,
            'tables' => $tables,
            'stats' => $this->stats($store, $tables),
        ];
    }

    /**
     * @param  Collection<int, PosTable>|null  $tables
     * @return array<string, mixed>
     */
    public function stats(Store $store, ?Collection $tables = null): array
    {
        $tables ??= PosTable::query()->where('store_id', $store->id)->get();

        $counts = [
            'total' => $tables->count(),
            'available' => 0,
            'occupied' => 0,
            'reserved' => 0,
            'cleaning' => 0,
            'inactive' => 0,
        ];

        foreach ($tables as $table) {
            $key = $table->status instanceof PosTableStatus ? $table->status->value : (string) $table->status;
            if (array_key_exists($key, $counts)) {
                $counts[$key]++;
            }
        }

        $todayFrom = now()->startOfDay();
        $todaySales = Sale::query()
            ->where('store_id', $store->id)
            ->whereNotNull('table_id')
            ->where('status', SaleStatus::Completed)
            ->where('completed_at', '>=', $todayFrom)
            ->get(['id', 'table_id', 'total', 'created_at', 'completed_at']);

        $openOrders = Sale::query()
            ->where('store_id', $store->id)
            ->whereNotNull('table_id')
            ->where('status', SaleStatus::Pending)
            ->count();

        $occupationMinutes = $todaySales
            ->filter(fn (Sale $sale) => $sale->created_at && $sale->completed_at)
            ->map(fn (Sale $sale) => $sale->created_at->diffInMinutes($sale->completed_at))
            ->filter(fn ($minutes) => $minutes >= 0);

        $usage = $todaySales->groupBy('table_id')->map->count()->sortDesc();
        $tableNames = $tables->keyBy('id');

        return [
            ...$counts,
            'open_orders' => $openOrders,
            'today_revenue' => (int) $todaySales->sum('total'),
            'today_tickets' => $todaySales->count(),
            'average_ticket' => $todaySales->count() > 0
                ? (int) round($todaySales->sum('total') / $todaySales->count())
                : 0,
            'average_occupation_minutes' => $occupationMinutes->count() > 0
                ? (int) round($occupationMinutes->avg())
                : 0,
            'most_used' => $usage->take(5)->map(function (int $count, string $tableId) use ($tableNames) {
                $table = $tableNames->get($tableId);

                return [
                    'table_id' => $tableId,
                    'name' => $table?->name ?? $tableId,
                    'tickets' => $count,
                ];
            })->values()->all(),
        ];
    }

    /** @param  array<string, mixed>  $payload */
    public function createZone(Store $store, array $payload): PosTableZone
    {
        return PosTableZone::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'name' => trim($payload['name']),
            'description' => $payload['description'] ?? null,
            'sort_order' => (int) ($payload['sort_order'] ?? 0),
            'is_active' => (bool) ($payload['is_active'] ?? true),
        ]);
    }

    /** @param  array<string, mixed>  $payload */
    public function updateZone(PosTableZone $zone, array $payload): PosTableZone
    {
        $zone->update([
            'name' => trim($payload['name'] ?? $zone->name),
            'description' => array_key_exists('description', $payload) ? $payload['description'] : $zone->description,
            'sort_order' => (int) ($payload['sort_order'] ?? $zone->sort_order),
            'is_active' => array_key_exists('is_active', $payload) ? (bool) $payload['is_active'] : $zone->is_active,
        ]);

        return $zone->fresh();
    }

    public function deleteZone(PosTableZone $zone): void
    {
        if ($zone->tables()->exists()) {
            throw ValidationException::withMessages([
                'zone' => ['Impossible de supprimer une zone encore utilisée par des tables.'],
            ]);
        }

        $zone->delete();
    }

    /** @param  array<string, mixed>  $payload */
    public function createTable(Store $store, array $payload): PosTable
    {
        $zone = $this->resolveZone($store, $payload['zone_id'] ?? null);

        return PosTable::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'zone_id' => $zone?->id,
            'name' => trim($payload['name']),
            'code' => $this->uniqueCode($store, $payload['code'] ?? $payload['name']),
            'capacity' => max(1, (int) ($payload['capacity'] ?? 2)),
            'description' => $payload['description'] ?? null,
            'status' => ! empty($payload['is_active']) || ! array_key_exists('is_active', $payload)
                ? PosTableStatus::Available
                : PosTableStatus::Inactive,
            'is_active' => (bool) ($payload['is_active'] ?? true),
        ]);
    }

    /** @param  array<string, mixed>  $payload */
    public function updateTable(PosTable $table, array $payload): PosTable
    {
        $zone = array_key_exists('zone_id', $payload)
            ? $this->resolveZone($table->store, $payload['zone_id'])
            : $table->zone;

        $isActive = array_key_exists('is_active', $payload) ? (bool) $payload['is_active'] : $table->is_active;
        $status = $table->status;

        if (! $isActive) {
            if ($table->currentSaleIsOpen()) {
                throw ValidationException::withMessages([
                    'is_active' => ['Impossible de désactiver une table avec une commande ouverte.'],
                ]);
            }
            $status = PosTableStatus::Inactive;
        } elseif ($table->status === PosTableStatus::Inactive) {
            $status = PosTableStatus::Available;
        }

        $code = $table->code;
        if (! empty($payload['code']) && strtoupper(trim($payload['code'])) !== $table->code) {
            $code = $this->uniqueCode($table->store, $payload['code'], $table->id);
        }

        $table->update([
            'zone_id' => $zone?->id,
            'name' => trim($payload['name'] ?? $table->name),
            'code' => $code,
            'capacity' => max(1, (int) ($payload['capacity'] ?? $table->capacity)),
            'description' => array_key_exists('description', $payload) ? $payload['description'] : $table->description,
            'is_active' => $isActive,
            'status' => $status,
        ]);

        $table->syncOccupancy();

        return $table->fresh(['zone']);
    }

    public function deactivate(PosTable $table): PosTable
    {
        return $this->updateTable($table, ['is_active' => false, 'name' => $table->name]);
    }

    /** @param  array<string, mixed>  $payload */
    public function setStatus(PosTable $table, array $payload, User $user): PosTable
    {
        $status = PosTableStatus::from($payload['status']);

        return DB::transaction(function () use ($table, $status, $user, $payload): PosTable {
            $locked = PosTable::query()->whereKey($table->id)->lockForUpdate()->firstOrFail();

            if ($status === PosTableStatus::Occupied) {
                throw ValidationException::withMessages([
                    'status' => ['Le statut occupé est géré automatiquement par les commandes ouvertes.'],
                ]);
            }

            if ($locked->currentSaleIsOpen() && $status !== PosTableStatus::Occupied) {
                throw ValidationException::withMessages([
                    'status' => ['Libérez ou payez la commande avant de changer le statut.'],
                ]);
            }

            if ($status === PosTableStatus::Inactive) {
                $locked->update(['is_active' => false, 'status' => PosTableStatus::Inactive]);
            } else {
                $locked->update([
                    'is_active' => true,
                    'status' => $status,
                ]);
            }

            PosTableEvent::record(
                table: $locked,
                type: 'status_changed',
                user: $user,
                payload: ['status' => $status->value],
                notes: $payload['notes'] ?? null,
            );

            return $locked->fresh(['zone', 'currentSale']);
        });
    }

    public function openOrder(PosTable $table, Store $store, User $user, bool $confirmReserved = false): Sale
    {
        return DB::transaction(function () use ($table, $store, $user, $confirmReserved): Sale {
            $locked = PosTable::query()
                ->with(['currentSale', 'reservations' => fn ($query) => $query->whereIn('status', ['pending', 'confirmed'])])
                ->whereKey($table->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($locked->store_id !== $store->id) {
                throw ValidationException::withMessages([
                    'table' => ['Cette table n’appartient pas à ce magasin.'],
                ]);
            }

            $locked->syncOccupancy();
            $locked->refresh();

            if ($locked->currentSaleIsOpen() && $locked->currentSale) {
                return $locked->currentSale->load(['items', 'processedBy', 'customer']);
            }

            if (! $locked->is_active || $locked->status === PosTableStatus::Inactive) {
                throw ValidationException::withMessages([
                    'table' => ['Cette table est inactive.'],
                ]);
            }

            if ($locked->status === PosTableStatus::Occupied) {
                throw ValidationException::withMessages([
                    'table' => ['Cette table a déjà une commande ouverte.'],
                ]);
            }

            if ($locked->status === PosTableStatus::Reserved && ! $confirmReserved) {
                throw ValidationException::withMessages([
                    'reserved' => ['Cette table est réservée. Confirmez pour ouvrir une commande.'],
                ]);
            }

            $sale = $this->saleEngine->openEmptyHold($store, $user, [
                'table_id' => $locked->id,
            ]);

            $locked->occupy($sale);

            $reservation = $locked->activeReservation();
            if ($reservation) {
                $reservation->update(['status' => 'seated']);
            }

            PosTableEvent::record(
                table: $locked,
                type: 'opened',
                user: $user,
                sale: $sale,
            );

            return $sale->load(['items', 'processedBy', 'customer']);
        });
    }

    public function cancelOrder(PosTable $table, User $user, ?string $reason = null): Sale
    {
        return DB::transaction(function () use ($table, $user, $reason): Sale {
            $locked = PosTable::query()->whereKey($table->id)->lockForUpdate()->firstOrFail();
            $sale = $this->requireOpenSale($locked);
            $voided = $this->saleEngine->voidPending($sale, $user, $reason);

            return $voided;
        });
    }

    public function transfer(PosTable $source, PosTable $destination, User $user): Sale
    {
        if ($source->id === $destination->id) {
            throw ValidationException::withMessages([
                'to_table_id' => ['Choisissez une table différente.'],
            ]);
        }

        return DB::transaction(function () use ($source, $destination, $user): Sale {
            $ids = [$source->id, $destination->id];
            sort($ids);
            $locked = PosTable::query()
                ->whereIn('id', $ids)
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            $from = $locked->get($source->id);
            $to = $locked->get($destination->id);

            if ($from === null || $to === null) {
                throw ValidationException::withMessages([
                    'table' => ['Table introuvable.'],
                ]);
            }

            if ($from->store_id !== $to->store_id) {
                throw ValidationException::withMessages([
                    'to_table_id' => ['La table de destination doit appartenir au même magasin.'],
                ]);
            }

            $sale = $this->requireOpenSale($from);
            $to->syncOccupancy();

            if ($to->currentSaleIsOpen()) {
                throw ValidationException::withMessages([
                    'to_table_id' => ['La table de destination est déjà occupée.'],
                ]);
            }

            if (! $to->is_active || $to->status === PosTableStatus::Inactive) {
                throw ValidationException::withMessages([
                    'to_table_id' => ['La table de destination est inactive.'],
                ]);
            }

            $sale->update(['table_id' => $to->id]);
            $from->release();
            $to->occupy($sale);

            PosTableEvent::record(
                table: $from,
                type: 'transferred',
                user: $user,
                sale: $sale,
                from: $from,
                to: $to,
            );
            PosTableEvent::record(
                table: $to,
                type: 'received',
                user: $user,
                sale: $sale,
                from: $from,
                to: $to,
            );

            return $sale->fresh(['items', 'processedBy', 'customer']);
        });
    }

    public function merge(PosTable $source, PosTable $destination, User $user): Sale
    {
        if ($source->id === $destination->id) {
            throw ValidationException::withMessages([
                'to_table_id' => ['Choisissez une table différente à fusionner.'],
            ]);
        }

        return DB::transaction(function () use ($source, $destination, $user): Sale {
            $ids = [$source->id, $destination->id];
            sort($ids);
            $locked = PosTable::query()
                ->whereIn('id', $ids)
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            $from = $locked->get($source->id);
            $to = $locked->get($destination->id);
            $sourceSale = $this->requireOpenSale($from);
            $destSale = $this->requireOpenSale($to);

            return $this->saleEngine->mergePending($destSale, $sourceSale, $user, [
                'table_id' => $to->id,
                'confirm_different_customers' => true,
            ]);
        });
    }

    /** @param  array<string, mixed>  $payload */
    public function reserve(PosTable $table, Store $store, User $user, array $payload): PosReservation
    {
        return DB::transaction(function () use ($table, $store, $user, $payload): PosReservation {
            $locked = PosTable::query()->whereKey($table->id)->lockForUpdate()->firstOrFail();
            $locked->syncOccupancy();

            if ($locked->currentSaleIsOpen()) {
                throw ValidationException::withMessages([
                    'table' => ['Impossible de réserver une table déjà occupée.'],
                ]);
            }

            if (! $locked->is_active) {
                throw ValidationException::withMessages([
                    'table' => ['Impossible de réserver une table inactive.'],
                ]);
            }

            $guestName = trim((string) ($payload['guest_name'] ?? ''));
            if ($guestName === '' && ! empty($payload['customer_id'])) {
                $guestName = (string) (\App\Models\Customer::query()->find($payload['customer_id'])?->name ?? '');
            }

            $reservation = PosReservation::query()->create([
                'tenant_id' => $store->tenant_id,
                'store_id' => $store->id,
                'table_id' => $locked->id,
                'customer_id' => $payload['customer_id'] ?? null,
                'reference' => $this->nextReservationReference($store->tenant_id),
                'guest_name' => $guestName !== '' ? $guestName : 'Client',
                'phone' => $payload['phone'] ?? null,
                'party_size' => max(1, (int) ($payload['party_size'] ?? $locked->capacity)),
                'reserved_at' => $payload['reserved_at'] ?? now(),
                'table_label' => $locked->name,
                'status' => $payload['status'] ?? 'confirmed',
                'notes' => $payload['notes'] ?? null,
                'created_by' => $user->id,
            ]);

            $locked->update([
                'status' => PosTableStatus::Reserved,
                'is_active' => true,
            ]);

            PosTableEvent::record(
                table: $locked,
                type: 'reserved',
                user: $user,
                payload: ['reservation_id' => $reservation->id],
            );

            return $reservation->load('customer:id,name,phone');
        });
    }

    /**
     * @param  array<string, mixed>  $filters
     * @return array{data: Collection<int, Sale>, meta: array<string, mixed>}
     */
    public function history(PosTable $table, array $filters = []): array
    {
        $limit = min(200, max(1, (int) ($filters['limit'] ?? 50)));

        $saleIds = PosTableEvent::query()
            ->where('table_id', $table->id)
            ->whereNotNull('sale_id')
            ->pluck('sale_id');

        $query = Sale::query()
            ->with(['customer:id,name', 'processedBy:id,name'])
            ->where(function ($builder) use ($table, $saleIds) {
                $builder->where('table_id', $table->id);
                if ($saleIds->isNotEmpty()) {
                    $builder->orWhereIn('id', $saleIds);
                }
            });

        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }
        if (! empty($filters['processed_by'])) {
            $query->where('processed_by', $filters['processed_by']);
        }
        if (! empty($filters['customer_id'])) {
            $query->where('customer_id', $filters['customer_id']);
        }
        if (isset($filters['min_total'])) {
            $query->where('total', '>=', (int) $filters['min_total']);
        }
        if (isset($filters['max_total'])) {
            $query->where('total', '<=', (int) $filters['max_total']);
        }
        if (! empty($filters['from'])) {
            $query->where('created_at', '>=', $filters['from']);
        }
        if (! empty($filters['to'])) {
            $query->where('created_at', '<=', $filters['to'].' 23:59:59');
        }

        $sales = $query->orderByDesc('created_at')->limit($limit)->get();

        return [
            'data' => $sales,
            'meta' => [
                'count' => $sales->count(),
                'limit' => $limit,
            ],
        ];
    }

    public function applyReservationToTable(?string $tableId, Store $store): void
    {
        if (! $tableId) {
            return;
        }

        $table = PosTable::query()
            ->where('store_id', $store->id)
            ->whereKey($tableId)
            ->first();

        if ($table === null || $table->currentSaleIsOpen()) {
            return;
        }

        if ($table->is_active) {
            $table->update(['status' => PosTableStatus::Reserved]);
        }
    }

    public function releaseReservation(PosReservation $reservation): void
    {
        if (! $reservation->table_id) {
            return;
        }

        $table = PosTable::query()->find($reservation->table_id);
        if ($table === null || $table->currentSaleIsOpen()) {
            return;
        }

        $stillReserved = PosReservation::query()
            ->where('table_id', $table->id)
            ->whereIn('status', ['pending', 'confirmed'])
            ->where('id', '!=', $reservation->id)
            ->exists();

        if (! $stillReserved && $table->status === PosTableStatus::Reserved) {
            $table->update(['status' => $table->is_active ? PosTableStatus::Available : PosTableStatus::Inactive]);
        }
    }

    private function requireOpenSale(PosTable $table): Sale
    {
        $sale = $table->current_sale_id
            ? Sale::query()->whereKey($table->current_sale_id)->lockForUpdate()->first()
            : null;

        if ($sale === null || $sale->status !== SaleStatus::Pending) {
            throw ValidationException::withMessages([
                'table' => ['Aucune commande ouverte sur cette table.'],
            ]);
        }

        return $sale;
    }

    private function resolveZone(Store $store, mixed $zoneId): ?PosTableZone
    {
        if (! $zoneId) {
            return null;
        }

        $zone = PosTableZone::query()
            ->where('store_id', $store->id)
            ->find($zoneId);

        if ($zone === null) {
            throw ValidationException::withMessages([
                'zone_id' => ['Zone introuvable pour ce magasin.'],
            ]);
        }

        return $zone;
    }

    private function uniqueCode(Store $store, string $source, ?string $ignoreId = null): string
    {
        $base = strtoupper(Str::of($source)->replaceMatches('/[^A-Za-z0-9]+/', '-')->trim('-')->substr(0, 32)->toString());
        if ($base === '') {
            $base = 'T';
        }

        $code = $base;
        $i = 2;
        while (
            PosTable::query()
                ->where('store_id', $store->id)
                ->when($ignoreId, fn ($query) => $query->where('id', '!=', $ignoreId))
                ->where('code', $code)
                ->exists()
        ) {
            $code = $base.'-'.$i;
            $i++;
        }

        return $code;
    }

    private function nextReservationReference(string $tenantId): string
    {
        $prefix = 'RES-'.now()->year.'-';
        $last = PosReservation::query()
            ->where('tenant_id', $tenantId)
            ->where('reference', 'like', $prefix.'%')
            ->orderByDesc('reference')
            ->value('reference');
        $next = 1;
        if (is_string($last) && preg_match('/(\d+)$/', $last, $matches)) {
            $next = ((int) $matches[1]) + 1;
        }

        return $prefix.str_pad((string) $next, 4, '0', STR_PAD_LEFT);
    }
}
