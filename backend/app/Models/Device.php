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
        'name',
        'device_type',
        'category',
        'pos_role',
        'master_device_id',
        'master_host',
        'platform',
        'app_version',
        'identifier',
        'connection_type',
        'ip_address',
        'port',
        'description',
        'registration_status',
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
        ];
    }

    public static function issueSyncToken(): string
    {
        do {
            $token = 'ITN-'.strtoupper(Str::random(4)).'-'.strtoupper(Str::random(4)).'-'.strtoupper(Str::random(4));
        } while (static::withoutGlobalScopes()->where('sync_token', $token)->exists());

        return $token;
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
