<?php

namespace App\Models;

use App\Enums\NotificationEvent;
use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class InboxNotification extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'user_id',
        'event',
        'title',
        'body',
        'context',
        'fingerprint',
        'read_at',
    ];

    protected function casts(): array
    {
        return [
            'event' => NotificationEvent::class,
            'context' => 'array',
            'read_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
