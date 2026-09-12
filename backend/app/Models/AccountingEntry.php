<?php

namespace App\Models;

use App\Enums\AccountingEntryType;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Validation\ValidationException;

class AccountingEntry extends Model
{
    use BelongsToTenant, HasUuids;

    public const UPDATED_AT = null;

    protected $fillable = [
        'tenant_id',
        'entry_type',
        'reference_type',
        'reference_id',
        'debit',
        'credit',
        'account_code',
        'description',
        'recorded_by',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'entry_type' => AccountingEntryType::class,
            'debit' => 'integer',
            'credit' => 'integer',
            'occurred_at' => 'datetime',
        ];
    }

    public static function booted(): void
    {
        static::updating(function (): void {
            throw ValidationException::withMessages([
                'accounting_entry' => ['Accounting entries are immutable.'],
            ]);
        });

        static::deleting(function (): void {
            throw ValidationException::withMessages([
                'accounting_entry' => ['Accounting entries are immutable.'],
            ]);
        });
    }

    public function recordedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }
}
