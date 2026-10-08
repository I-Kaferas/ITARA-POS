<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PlatformBackup extends Model
{
    use HasUuids;

    protected $fillable = [
        'type',
        'trigger',
        'status',
        'disk',
        'path',
        'size_bytes',
        'checksum',
        'includes',
        'meta',
        'error_message',
        'started_at',
        'finished_at',
        'verified_at',
        'expires_at',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'includes' => 'array',
            'meta' => 'array',
            'size_bytes' => 'integer',
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
            'verified_at' => 'datetime',
            'expires_at' => 'datetime',
        ];
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function restores(): HasMany
    {
        return $this->hasMany(PlatformBackupRestore::class, 'backup_id');
    }

    public function isCompleted(): bool
    {
        return $this->status === 'completed';
    }
}
