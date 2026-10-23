<?php

namespace App\Models;

use App\Enums\QrOrderStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class QrOrder extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'pos_table_id',
        'session_id',
        'sale_id',
        'source',
        'status',
        'guest_locale',
        'idempotency_key',
        'rejection_reason',
        'approved_by',
        'approved_at',
        'rejected_by',
        'rejected_at',
        'kitchen_ticket_code',
        'subtotal',
        'tax_total',
        'total',
        'currency',
    ];

    protected function casts(): array
    {
        return [
            'status' => QrOrderStatus::class,
            'approved_at' => 'datetime',
            'rejected_at' => 'datetime',
            'subtotal' => 'integer',
            'tax_total' => 'integer',
            'total' => 'integer',
        ];
    }

    public function table(): BelongsTo
    {
        return $this->belongsTo(PosTable::class, 'pos_table_id');
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(QrTableSession::class, 'session_id');
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(QrOrderItem::class)->orderBy('sort_order');
    }

    public function approver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }
}
