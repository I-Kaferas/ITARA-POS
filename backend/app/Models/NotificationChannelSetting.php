<?php

namespace App\Models;

use App\Enums\NotificationChannel;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class NotificationChannelSetting extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'channel',
        'enabled',
        'config',
    ];

    protected function casts(): array
    {
        return [
            'channel' => NotificationChannel::class,
            'enabled' => 'boolean',
            'config' => 'encrypted:array',
        ];
    }
}
