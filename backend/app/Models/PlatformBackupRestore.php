<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PlatformBackupRestore extends Model
{
    use HasUuids;

    protected $fillable = [
        'backup_id',
        'mode',
        'status',
        'options',
        'report',
        'error_message',
        'started_by',
        'started_at',
        'finished_at',
    ];

    protected function casts(): array
    {
        return [
            'options' => 'array',
            'report' => 'array',
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
        ];
    }

    public function backup(): BelongsTo
    {
        return $this->belongsTo(PlatformBackup::class, 'backup_id');
    }

    public function starter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'started_by');
    }
}
