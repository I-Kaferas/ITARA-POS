<?php

namespace App\Models;

use App\Enums\SaleDocumentFormat;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleReceipt extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'sale_id',
        'receipt_number',
        'format',
        'printed_by',
        'device_id',
        'printed_at',
        'reprint_count',
    ];

    protected function casts(): array
    {
        return [
            'format' => SaleDocumentFormat::class,
            'printed_at' => 'datetime',
            'reprint_count' => 'integer',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function printedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'printed_by');
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(Device::class);
    }

    /** @return array<string, mixed> */
    public function toSummaryArray(): array
    {
        return [
            'id' => $this->id,
            'sale_id' => $this->sale_id,
            'receipt_number' => $this->receipt_number,
            'format' => $this->format->value,
            'format_label' => $this->format->label(),
            'printed_at' => $this->printed_at?->toIso8601String(),
            'printed_by' => $this->printedBy?->only(['id', 'name']),
            'device_id' => $this->device_id,
            'reprint_count' => $this->reprint_count,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
