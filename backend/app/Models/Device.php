<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Support\Str;

class Device extends Model
{
    use BelongsToTenant, HasUuids;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'branch_id',
        'user_id',
        'code',
        'name',
        'device_type',
        'category',
        'pos_role',
        'master_device_id',
        'master_host',
        'platform',
        'app_version',
        'local_server',
        'identifier',
        'connection_type',
        'ip_address',
        'port',
        'description',
        'registration_status',
        'status',
        'revoked_at',
        'sync_token',
        'token_generated_at',
        'registered_at',
        'is_active',
        'last_sync_at',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'port' => 'integer',
            'last_sync_at' => 'datetime',
            'token_generated_at' => 'datetime',
            'registered_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public static function issueSyncToken(): string
    {
        do {
            $token = 'ITN-'.strtoupper(Str::random(4)).'-'.strtoupper(Str::random(4)).'-'.strtoupper(Str::random(4));
        } while (static::withoutGlobalScopes()->where('sync_token', $token)->exists());

        return $token;
    }

    public static function nextCode(string $tenantId): string
    {
        $latest = static::withoutGlobalScopes()
            ->where('tenant_id', $tenantId)
            ->where('code', 'like', 'DEVICE-%')
            ->orderByDesc('code')
            ->value('code');

        $number = 1;
        if (is_string($latest) && preg_match('/DEVICE-(\d+)/', $latest, $matches) === 1) {
            $number = ((int) $matches[1]) + 1;
        }

        return 'DEVICE-'.str_pad((string) $number, 3, '0', STR_PAD_LEFT);
    }

    public function isRevoked(): bool
    {
        return $this->status === 'revoked' || ! $this->is_active;
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function masterDevice(): BelongsTo
    {
        return $this->belongsTo(Device::class, 'master_device_id');
    }

    public function warehouses(): BelongsToMany
    {
        return $this->belongsToMany(Warehouse::class, 'device_warehouse');
    }
}
