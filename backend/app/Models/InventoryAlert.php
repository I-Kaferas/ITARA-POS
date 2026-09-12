<?php

namespace App\Models;

use App\Enums\InventoryAlertStatus;
use App\Enums\InventoryAlertType;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class InventoryAlert extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'warehouse_id',
        'product_id',
        'batch_id',
        'alert_type',
        'status',
        'quantity_on_hand',
        'threshold_value',
        'expires_at',
        'message',
        'acknowledged_at',
        'acknowledged_by',
        'resolved_at',
    ];

    protected function casts(): array
    {
        return [
            'alert_type' => InventoryAlertType::class,
            'status' => InventoryAlertStatus::class,
            'quantity_on_hand' => 'integer',
            'threshold_value' => 'integer',
            'expires_at' => 'date',
            'acknowledged_at' => 'datetime',
            'resolved_at' => 'datetime',
        ];
    }

    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(Batch::class);
    }

    public function acknowledgedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'acknowledged_by');
    }

    public function isActive(): bool
    {
        return $this->status === InventoryAlertStatus::Active;
    }
}
