<?php

namespace App\Services\Performance;

use App\Tenancy\TenantCache;
use Closure;

class ReadCache
{
    public function __construct(private readonly TenantCache $cache) {}

    public function remember(string $bucket, string $key, Closure $callback): mixed
    {
        $ttl = (int) config('performance.read_cache_seconds', 0);
        if ($ttl <= 0) {
            return $callback();
        }

        $version = (int) $this->cache->get($this->versionKey($bucket), 1);

        return $this->cache->remember($bucket.':'.$version.':'.$key, $ttl, $callback);
    }

    public function bump(string $bucket): void
    {
        $key = $this->versionKey($bucket);
        $next = ((int) $this->cache->get($key, 1)) + 1;
        $this->cache->put($key, $next, 86400);
    }

    private function versionKey(string $bucket): string
    {
        return 'perf:'.$bucket.':v';
    }
}
