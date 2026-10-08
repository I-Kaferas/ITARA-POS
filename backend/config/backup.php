<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Storage
    |--------------------------------------------------------------------------
    |
    | Platform backups are written to a private disk under a dedicated prefix.
    | Do not reuse terminal-backups/ (device offline dumps).
    |
    */

    'disk' => env('BACKUP_DISK', 'local'),

    'path' => env('BACKUP_PATH', 'platform-backups'),

    /*
    |--------------------------------------------------------------------------
    | Automatic schedule
    |--------------------------------------------------------------------------
    */

    'auto_enabled' => (bool) env('BACKUP_AUTO_ENABLED', true),

    'schedule_time' => env('BACKUP_SCHEDULE_TIME', '02:30'),

    'default_type' => env('BACKUP_DEFAULT_TYPE', 'full'), // database|files|full

    /*
    |--------------------------------------------------------------------------
    | Retention (grandfather-father-son)
    |--------------------------------------------------------------------------
    */

    'retention' => [
        'daily' => (int) env('BACKUP_KEEP_DAILY', 7),
        'weekly' => (int) env('BACKUP_KEEP_WEEKLY', 4),
        'monthly' => (int) env('BACKUP_KEEP_MONTHLY', 6),
    ],

    /*
    |--------------------------------------------------------------------------
    | Disaster recovery targets
    |--------------------------------------------------------------------------
    */

    'rpo_hours' => (int) env('BACKUP_RPO_HOURS', 36),

    'rto_minutes' => (int) env('BACKUP_RTO_MINUTES', 120),

    /*
    |--------------------------------------------------------------------------
    | File sources included in a files/full backup
    |--------------------------------------------------------------------------
    |
    | Each entry is [disk => relative path or '' for whole disk].
    | platform-backups itself is always excluded.
    |
    */

    'file_sources' => [
        ['disk' => 'public', 'path' => ''],
        ['disk' => 'local', 'path' => ''],
    ],

    'exclude_prefixes' => [
        'platform-backups',
        'framework',
        'logs',
    ],

    /*
    |--------------------------------------------------------------------------
    | Optional offsite mirror (S3-compatible)
    |--------------------------------------------------------------------------
    */

    'offsite_disk' => env('BACKUP_OFFSITE_DISK'),

];
