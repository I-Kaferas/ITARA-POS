<?php

namespace App\Models;

use App\Enums\PosTableStatus;
use App\Enums\SaleStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PosTable extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'zone_id',
        'name',
        'code',
        'capacity',
        'description',
        'status',
        'is_active',
        'current_sale_id',
    ];

    protected function casts(): array
    {
        return [
            'capacity' => 'integer',
            'is_active' => 'boolean',
            'status' => PosTableStatus::class,
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function zone(): BelongsTo
    {
        return $this->belongsTo(PosTableZone::class, 'zone_id');
    }

    public function currentSale(): BelongsTo
    {
        return $this->belongsTo(Sale::class, 'current_sale_id');
    }

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class, 'table_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(PosTableEvent::class, 'table_id')->orderByDesc('created_at');
    }

    public function reservations(): HasMany
    {
        return $this->hasMany(PosReservation::class, 'table_id');
    }

    public function activeReservation(): ?PosReservation
    {
        if ($this->relationLoaded('reservations')) {
            return $this->reservations
                ->first(fn (PosReservation $reservation) => in_array($reservation->status, ['pending', 'confirmed'], true));
        }

        return $this->reservations()
            ->whereIn('status', ['pending', 'confirmed'])
            ->orderBy('reserved_at')
            ->first();
    }

    public function occupy(Sale $sale): void
    {
        $this->forceFill([
            'current_sale_id' => $sale->id,
            'status' => PosTableStatus::Occupied,
            'is_active' => true,
        ])->save();
    }

    public function release(?PosTableStatus $next = null): void
    {
        $status = $next ?? $this->statusAfterRelease();

        $this->forceFill([
            'current_sale_id' => null,
            'status' => $status,
        ])->save();
    }

    public function statusAfterRelease(): PosTableStatus
    {
        if (! $this->is_active) {
            return PosTableStatus::Inactive;
        }

        if ($this->activeReservation() !== null) {
            return PosTableStatus::Reserved;
        }

        return PosTableStatus::Available;
    }

    public static function releaseSale(string $saleId, string $reason = 'released'): void
    {
        $tables = static::query()
            ->where('current_sale_id', $saleId)
            ->lockForUpdate()
            ->get();

        foreach ($tables as $table) {
            $sale = $table->relationLoaded('currentSale')
                ? $table->currentSale
                : Sale::query()->find($saleId);
            $table->release();
            PosTableEvent::record(
                table: $table,
                type: $reason,
                sale: $sale,
                payload: ['sale_id' => $saleId],
            );
        }
    }

    public function syncOccupancy(): void
    {
        if (! $this->is_active) {
            $this->forceFill([
                'status' => PosTableStatus::Inactive,
                'current_sale_id' => $this->currentSaleIsOpen() ? $this->current_sale_id : null,
            ])->save();

            return;
        }

        if ($this->currentSaleIsOpen()) {
            if ($this->status !== PosTableStatus::Occupied) {
                $this->forceFill(['status' => PosTableStatus::Occupied])->save();
            }

            return;
        }

        if ($this->current_sale_id !== null) {
            $this->forceFill(['current_sale_id' => null])->save();
        }

        if (in_array($this->status, [PosTableStatus::Cleaning, PosTableStatus::Reserved], true)) {
            if ($this->status === PosTableStatus::Reserved && $this->activeReservation() !== null) {
                return;
            }
            if ($this->status === PosTableStatus::Cleaning) {
                return;
            }
        }

        $next = $this->activeReservation() !== null
            ? PosTableStatus::Reserved
            : PosTableStatus::Available;

        if ($this->status !== $next) {
            $this->forceFill(['status' => $next])->save();
        }
    }

    public function currentSaleIsOpen(): bool
    {
        $sale = $this->relationLoaded('currentSale')
            ? $this->currentSale
            : ($this->current_sale_id ? Sale::query()->find($this->current_sale_id) : null);

        return $sale !== null && $sale->status === SaleStatus::Pending;
    }

    /** @return array<string, mixed> */
    public function toFloorArray(): array
    {
        $sale = $this->relationLoaded('currentSale') ? $this->currentSale : null;
        if ($sale && $sale->status !== SaleStatus::Pending) {
            $sale = null;
        }

        $reservation = $this->activeReservation();
        $itemCount = 0;
        if ($sale) {
            $itemCount = $sale->relationLoaded('items')
                ? (int) $sale->items->sum('quantity')
                : (int) $sale->items()->sum('quantity');
        }

        return [
            'id' => $this->id,
            'name' => $this->name,
            'code' => $this->code,
            'capacity' => $this->capacity,
            'zone_id' => $this->zone_id,
            'zone' => $this->relationLoaded('zone') && $this->zone
                ? $this->zone->only(['id', 'name'])
                : null,
            'description' => $this->description,
            'status' => $this->status->value,
            'is_active' => $this->is_active,
            'current_sale_id' => $sale?->id,
            'current_sale' => $sale ? [
                'id' => $sale->id,
                'reference' => $sale->reference,
                'status' => $sale->status->value,
                'total' => $sale->total,
                'subtotal' => $sale->subtotal,
                'tax_total' => $sale->tax_total,
                'discount_total' => $sale->discount_total,
                'item_count' => $itemCount,
                'opened_at' => $sale->created_at?->toIso8601String(),
                'server' => $sale->relationLoaded('processedBy') && $sale->processedBy
                    ? $sale->processedBy->only(['id', 'name'])
                    : null,
                'customer' => $sale->relationLoaded('customer') && $sale->customer
                    ? $sale->customer->only(['id', 'name'])
                    : null,
            ] : null,
            'reservation' => $reservation ? [
                'id' => $reservation->id,
                'reference' => $reservation->reference,
                'guest_name' => $reservation->guest_name,
                'party_size' => $reservation->party_size,
                'reserved_at' => $reservation->reserved_at?->toIso8601String(),
                'status' => $reservation->status,
                'customer' => $reservation->relationLoaded('customer') && $reservation->customer
                    ? $reservation->customer->only(['id', 'name', 'phone'])
                    : null,
                'notes' => $reservation->notes,
            ] : null,
        ];
    }
}
