<?php

namespace App\Http\Middleware;

use App\Services\Sync\OfflineSyncService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Stores a successful write keyed by X-Client-UUID so a lost response
 * can be acknowledged later without applying the transaction twice.
 */
class RecordOfflineTransaction
{
    public function __construct(private readonly OfflineSyncService $offline) {}

    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        if (! $request->isMethodSafe() && $request->headers->has('X-Client-UUID')) {
            try {
                $this->offline->rememberHttp($request, $response);
            } catch (\Throwable) {
                // The domain write already succeeded. A missing idempotency
                // marker must not turn that success into an error response.
            }
        }

        return $response;
    }
}
