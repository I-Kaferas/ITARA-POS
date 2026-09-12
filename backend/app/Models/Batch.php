<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Batch extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'product_id',
        'batch_number',
        'manufactured_at',
        'expires_at',
        'unit_cost',
        'received_at',
        'supplier_id',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'manufactured_at' => 'date',
            'expires_at' => 'date',
            'unit_cost' => 'integer',
            'received_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function serialNumbers(): HasMany
    {
        return $this->hasMany(SerialNumber::class);
    }

    public function movements(): HasMany
    {
        return $this->hasMany(InventoryMovement::class);
    }

    public function stockBalances(): HasMany
    {
        return $this->hasMany(StockBalance::class);
    }

    public function alerts(): HasMany
    {
        return $this->hasMany(InventoryAlert::class);
    }

    public function isExpired(): bool
    {
        return $this->expires_at !== null && $this->expires_at->isPast();
    }

    public function isExpiringSoon(?int $withinDays = null): bool
    {
        if ($this->expires_at === null || $this->isExpired()) {
            return false;
        }

        $days = $withinDays ?? (int) config('inventory.expiring_soon_days', 30);

        return $this->expires_at->lte(now()->addDays($days));
    }

    public function quantityInWarehouse(Warehouse $warehouse): int
    {
        return (int) $this->stockBalances()
            ->where('warehouse_id', $warehouse->id)
            ->sum('quantity_on_hand');
    }

    public function totalQuantityOnHand(): int
    {
        return (int) $this->stockBalances()->sum('quantity_on_hand');
    }
}
