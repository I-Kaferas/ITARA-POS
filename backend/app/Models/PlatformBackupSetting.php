<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PlatformBackupSetting extends Model
{
    protected $table = 'platform_backup_settings';

    protected $fillable = [
        'auto_enabled',
        'schedule_time',
        'default_type',
        'keep_daily',
        'keep_weekly',
        'keep_monthly',
        'rpo_hours',
        'rto_minutes',
    ];

    protected function casts(): array
    {
        return [
            'auto_enabled' => 'boolean',
            'keep_daily' => 'integer',
            'keep_weekly' => 'integer',
            'keep_monthly' => 'integer',
            'rpo_hours' => 'integer',
            'rto_minutes' => 'integer',
        ];
    }
}
