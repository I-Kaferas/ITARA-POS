<?php

namespace App\Models;

use App\Enums\SaleDocumentFormat;
use App\Enums\SaleInvoiceStatus;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleInvoice extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_id',
        'invoice_number',
        'status',
        'format',
        'issued_by',
        'issued_at',
        'cancelled_by',
        'cancelled_at',
        'storage_path',
    ];

    protected function casts(): array
    {
        return [
            'status' => SaleInvoiceStatus::class,
            'format' => SaleDocumentFormat::class,
            'issued_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function issuedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'issued_by');
    }

    public function cancelledBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cancelled_by');
    }

    /** @return array<string, mixed> */
    public function toSummaryArray(): array
    {
        return [
            'id' => $this->id,
            'sale_id' => $this->sale_id,
            'invoice_number' => $this->invoice_number,
            'status' => $this->status->value,
            'format' => $this->format->value,
            'format_label' => $this->format->label(),
            'issued_at' => $this->issued_at?->toIso8601String(),
            'issued_by' => $this->issuedBy?->only(['id', 'name']),
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),
            'storage_path' => $this->storage_path,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
