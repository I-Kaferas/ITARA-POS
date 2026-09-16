<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PosTableEvent extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'table_id',
        'sale_id',
        'user_id',
        'type',
        'from_table_id',
        'to_table_id',
        'payload',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
        ];
    }

    public function table(): BelongsTo
    {
        return $this->belongsTo(PosTable::class, 'table_id');
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    public static function record(
        PosTable $table,
        string $type,
        ?User $user = null,
        ?Sale $sale = null,
        ?PosTable $from = null,
        ?PosTable $to = null,
        array $payload = [],
        ?string $notes = null,
    ): self {
        return self::query()->create([
            'tenant_id' => $table->tenant_id,
            'store_id' => $table->store_id,
            'table_id' => $table->id,
            'sale_id' => $sale?->id,
            'user_id' => $user?->id,
            'type' => $type,
            'from_table_id' => $from?->id,
            'to_table_id' => $to?->id,
            'payload' => $payload ?: null,
            'notes' => $notes,
        ]);
    }
}
