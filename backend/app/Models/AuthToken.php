<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AuthToken extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'device_name',
        'access_token_hash',
        'refresh_token_hash',
        'ip_address',
        'user_agent',
        'last_used_at',
        'access_expires_at',
        'refresh_expires_at',
        'revoked_at',
    ];

    protected function casts(): array
    {
        return [
            'last_used_at' => 'datetime',
            'access_expires_at' => 'datetime',
            'refresh_expires_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isAccessValid(): bool
    {
        return $this->revoked_at === null && $this->access_expires_at->isFuture();
    }

    public function isRefreshValid(): bool
    {
        return $this->revoked_at === null && $this->refresh_expires_at->isFuture();
    }

    public function revoke(): void
    {
        $this->update(['revoked_at' => now()]);
    }
}
