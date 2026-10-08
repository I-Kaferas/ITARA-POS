<?php

namespace App\Tenancy;

use Closure;
use Illuminate\Support\Facades\Cache;

class TenantCache
{
    public function __construct(private readonly TenantContext $context) {}

    public function key(string $key): string
    {
        $tenantId = $this->context->id() ?? 'platform';

        return 'tenant:'.$tenantId.':'.$key;
    }

    public function get(string $key, mixed $default = null): mixed
    {
        return Cache::get($this->key($key), $default);
    }

    public function put(string $key, mixed $value, \DateTimeInterface|\DateInterval|int|null $ttl = null): bool
    {
        return Cache::put($this->key($key), $value, $ttl);
    }

    public function remember(string $key, \DateTimeInterface|\DateInterval|int|null $ttl, Closure $callback): mixed
    {
        return Cache::remember($this->key($key), $ttl, $callback);
    }

    public function forget(string $key): bool
    {
        return Cache::forget($this->key($key));
    }
}
