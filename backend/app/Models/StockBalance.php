<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use App\Services\Inventory\StockBalanceGuard;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Validation\ValidationException;

class StockBalance extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'warehouse_id',
        'product_id',
        'product_variant_id',
        'batch_id',
        'quantity_on_hand',
        'quantity_reserved',
        'last_movement_id',
    ];

    protected function casts(): array
    {
        return [
            'quantity_on_hand' => 'integer',
            'quantity_reserved' => 'integer',
        ];
    }

    public static function booted(): void
    {
        static::creating(function (StockBalance $balance): void {
            if (! StockBalanceGuard::isAuthorized()) {
                throw ValidationException::withMessages([
                    'stock_balance' => ['Stock balances can only be created via inventory movements.'],
                ]);
            }
        });

        static::updating(function (StockBalance $balance): void {
            if (! StockBalanceGuard::isAuthorized()) {
                throw ValidationException::withMessages([
                    'stock_balance' => ['Stock quantities can only be modified via inventory movements.'],
                ]);
            }

            if ($balance->isDirty('quantity_on_hand') && $balance->quantity_on_hand < 0) {
                throw ValidationException::withMessages([
                    'quantity_on_hand' => ['Insufficient stock for this operation.'],
                ]);
            }
        });

        static::deleting(function (): void {
            throw ValidationException::withMessages([
                'stock_balance' => ['Stock balances cannot be deleted directly.'],
            ]);
        });
    }

    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function productVariant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class);
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(Batch::class);
    }

    public function lastMovement(): BelongsTo
    {
        return $this->belongsTo(InventoryMovement::class, 'last_movement_id');
    }

    public function quantityAvailable(): int
    {
        return max(0, $this->quantity_on_hand - $this->quantity_reserved);
    }
}
