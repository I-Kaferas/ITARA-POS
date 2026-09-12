<?php

namespace App\Models;

use App\Enums\InventoryMovementType;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Validation\ValidationException;

class InventoryMovement extends Model
{
    use BelongsToTenant, HasUuids;

    public const UPDATED_AT = null;

    protected $fillable = [
        'tenant_id',
        'warehouse_id',
        'product_id',
        'product_variant_id',
        'batch_id',
        'serial_number_id',
        'movement_type',
        'quantity',
        'unit_cost',
        'reference_type',
        'reference_id',
        'source_warehouse_id',
        'destination_warehouse_id',
        'performed_by',
        'notes',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'movement_type' => InventoryMovementType::class,
            'quantity' => 'integer',
            'unit_cost' => 'integer',
            'occurred_at' => 'datetime',
        ];
    }

    public static function booted(): void
    {
        static::updating(function (): void {
            throw ValidationException::withMessages([
                'inventory_movement' => ['Inventory movements are immutable and cannot be updated.'],
            ]);
        });

        static::deleting(function (): void {
            throw ValidationException::withMessages([
                'inventory_movement' => ['Inventory movements are immutable and cannot be deleted.'],
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

    public function serialNumber(): BelongsTo
    {
        return $this->belongsTo(SerialNumber::class);
    }

    public function sourceWarehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class, 'source_warehouse_id');
    }

    public function destinationWarehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class, 'destination_warehouse_id');
    }

    public function performedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'performed_by');
    }

    public function reference(): MorphTo
    {
        return $this->morphTo(__FUNCTION__, 'reference_type', 'reference_id');
    }
}
