<?php

namespace App\Models;

use App\Enums\TransactionPaymentStatus;
use App\Enums\TransactionStatus;
use App\Enums\TransactionType;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class Transaction extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'party_id',
        'reference',
        'idempotency_key',
        'branch_id',
        'user_id',
        'type',
        'date',
        'status',
        'amount',
        'currency',
        'payment_status',
        'source_type',
        'source_id',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'type' => TransactionType::class,
            'date' => 'date',
            'status' => TransactionStatus::class,
            'amount' => 'integer',
            'payment_status' => TransactionPaymentStatus::class,
            'metadata' => 'array',
        ];
    }

    public function party(): BelongsTo
    {
        return $this->belongsTo(Party::class);
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function source(): MorphTo
    {
        return $this->morphTo();
    }

    /** @return array<string, mixed> */
    public function toSummaryArray(): array
    {
        return [
            'id' => $this->id,
            'uuid' => $this->id,
            'transaction_id' => $this->id,
            'reference' => $this->reference,
            'idempotency_key' => $this->idempotency_key,
            'tenant_id' => $this->tenant_id,
            'branch_id' => $this->branch_id,
            'user_id' => $this->user_id,
            'type' => $this->type->value,
            'date' => $this->date?->toDateString(),
            'status' => $this->status->value,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'payment_status' => $this->payment_status->value,
            'source_type' => $this->source_type,
            'source_id' => $this->source_id,
            'metadata' => $this->metadata,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
            'branch' => $this->relationLoaded('branch') && $this->branch
                ? $this->branch->only(['id', 'name', 'code'])
                : null,
            'user' => $this->relationLoaded('user') && $this->user
                ? $this->user->only(['id', 'name'])
                : null,
        ];
    }
}
