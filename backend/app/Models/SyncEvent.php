<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Validation\ValidationException;

class SyncEvent extends Model
{
    use BelongsToTenant, HasUuids;

    public const UPDATED_AT = null;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'device_id',
        'sequence',
        'event_type',
        'entity_type',
        'entity_id',
        'payload',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'sequence' => 'integer',
            'payload' => 'array',
            'occurred_at' => 'datetime',
        ];
    }

    public static function booted(): void
    {
        static::updating(function (): void {
            throw ValidationException::withMessages([
                'sync_event' => ['Sync events are immutable.'],
            ]);
        });

        static::deleting(function (): void {
            throw ValidationException::withMessages([
                'sync_event' => ['Sync events are immutable.'],
            ]);
        });
    }

    public static function recordCompletedSale(Sale $sale, SaleReceipt $receipt): self
    {
        $last = static::query()
            ->where('tenant_id', $sale->tenant_id)
            ->orderByDesc('sequence')
            ->lockForUpdate()
            ->first();

        return static::query()->create([
            'tenant_id' => $sale->tenant_id,
            'store_id' => $sale->store_id,
            'device_id' => $sale->device_id,
            'sequence' => ($last?->sequence ?? 0) + 1,
            'event_type' => 'sale.completed',
            'entity_type' => 'sale',
            'entity_id' => $sale->id,
            'payload' => [
                'reference' => $sale->reference,
                'receipt_number' => $receipt->receipt_number,
                'payment_transaction_number' => $sale->payment_transaction_number,
                'total' => $sale->total,
                'currency' => $sale->currency,
            ],
            'occurred_at' => now(),
        ]);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    /** @return array<string, mixed> */
    public function toSummaryArray(): array
    {
        return [
            'id' => $this->id,
            'sequence' => $this->sequence,
            'event_type' => $this->event_type,
            'entity_type' => $this->entity_type,
            'entity_id' => $this->entity_id,
            'store_id' => $this->store_id,
            'device_id' => $this->device_id,
            'payload' => $this->payload,
            'occurred_at' => $this->occurred_at?->toIso8601String(),
        ];
    }
}
