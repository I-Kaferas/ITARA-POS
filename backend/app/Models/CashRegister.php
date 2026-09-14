<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class CashRegister extends Model
{
    use BelongsToTenant, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'store_id',
        'device_id',
        'name',
        'code',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(Device::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(CashRegisterSession::class);
    }

    public function openSession(): HasOne
    {
        return $this->hasOne(CashRegisterSession::class)
            ->where('status', 'open')
            ->latest('opened_at');
    }

    public function movements(): HasMany
    {
        return $this->hasMany(CashMovement::class);
    }

    public function openCashierShift(): HasOne
    {
        return $this->hasOne(CashierShift::class)->where('status', 'open')->latest('opened_at');
    }

    public static function ensureForStore(Store $store): self
    {
        $existing = static::query()
            ->where('store_id', $store->id)
            ->where('is_active', true)
            ->orderBy('name')
            ->first();

        if ($existing) {
            return $existing;
        }

        $base = 'C-'.strtoupper((string) ($store->code ?: 'POS'));
        $code = $base;
        $suffix = 2;
        while (static::withTrashed()->where('code', $code)->exists()) {
            $code = $base.'-'.$suffix;
            $suffix++;
        }

        return static::query()->create([
            'tenant_id' => $store->tenant_id,
            'store_id' => $store->id,
            'name' => 'Caisse '.$store->name,
            'code' => $code,
            'is_active' => true,
        ]);
    }
}
